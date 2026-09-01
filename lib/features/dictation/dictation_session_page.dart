import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../notebook/notebook_controller.dart';
import '../study_coach/study_assignments_repository.dart';
import 'dictation_controller.dart';
import 'models/dictation_item.dart';
import 'models/dictation_next_result.dart';
import 'models/dictation_score.dart';

class DictationSessionPage extends ConsumerStatefulWidget {
  const DictationSessionPage({
    super.key,
    required this.items,
    this.calibrated = false,
    this.focusTags = const [],
  });

  final List<DictationItem> items;
  final bool calibrated;
  final List<String> focusTags;

  @override
  ConsumerState<DictationSessionPage> createState() =>
      _DictationSessionPageState();
}

class _DictationSessionPageState extends ConsumerState<DictationSessionPage> {
  final _answerController = TextEditingController();
  final _player = AudioPlayer();
  final Map<String, String> _audioUrlCache = {};

  int _index = 0;
  bool _loadingAudio = false;
  bool _checking = false;
  bool _saving = false;
  bool _retriedAlmost = false;
  DictationGradingResult? _checked;
  DictationReinforceResult? _reinforce;
  bool _loadingReinforce = false;
  final List<int> _scores = [];
  String? _audioError;

  DictationItem get _currentItem => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _answerController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _answerController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    setState(() {
      _loadingAudio = true;
      _audioError = null;
    });
    try {
      var url = _audioUrlCache[_currentItem.id];
      if (url == null) {
        url = await ref
            .read(dictationRepositoryProvider)
            .fetchAudioUrl(
              text: _currentItem.promptText,
              language: _currentItem.language,
            );
        if (url != null) _audioUrlCache[_currentItem.id] = url;
      }
      if (url == null) {
        setState(() => _audioError = 'Não foi possível gerar o áudio.');
        return;
      }
      await _player.setUrl(url);
      await _player.seek(Duration.zero);
      unawaited(_player.play());
    } catch (e, st) {
      debugPrint('DICTATION_AUDIO_ERROR: $e\n$st');
      if (mounted) {
        setState(() => _audioError = 'Não foi possível tocar o áudio.');
      }
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _check({bool forceFinal = false}) async {
    final local = scoreDictationAnswer(
      _currentItem.promptText,
      _answerController.text,
    );
    setState(() => _checking = true);
    final aiRow = await ref
        .read(dictationRepositoryProvider)
        .fetchAiGrade(
          expected: _currentItem.promptText,
          answer: _answerController.text,
          language: _currentItem.language,
          local: local,
        );
    if (!mounted) return;
    final merged = mergeDictationGrades(local, aiRow);
    final almost =
        !forceFinal &&
        !_retriedAlmost &&
        isDictationAlmostCorrect(merged.score);
    setState(() {
      _checked = merged;
      _checking = false;
    });
    if (!almost && (merged.mistakes.isNotEmpty || merged.score < 100)) {
      unawaited(_loadReinforce(merged));
    }
  }

  Future<void> _loadReinforce(DictationGradingResult score) async {
    setState(() {
      _loadingReinforce = true;
      _reinforce = null;
    });
    final result = await ref
        .read(dictationRepositoryProvider)
        .fetchReinforce(
          item: _currentItem,
          answer: _answerController.text,
          score: score,
        );
    if (!mounted) return;
    setState(() {
      _reinforce = result;
      _loadingReinforce = false;
    });
    if (result != null) {
      try {
        await ref
            .read(notebookControllerProvider.notifier)
            .addAiExplanation(
              content: result.notebookContent(),
              language: _currentItem.language,
              title: result.notebookTitle(),
              aiSource: 'dictation_reinforce',
            );
      } catch (_) {}
    }
  }

  Future<void> _retryAlmost() async {
    setState(() {
      _retriedAlmost = true;
      _checked = null;
      _reinforce = null;
    });
  }

  Future<void> _saveAndNext() async {
    final checked = _checked;
    if (checked == null) return;
    setState(() => _saving = true);
    final repo = ref.read(dictationRepositoryProvider);
    try {
      final attemptId = await repo.saveAttempt(
        dictationItemId: _currentItem.id,
        answerText: _answerController.text.trim(),
        score: checked,
      );
      unawaited(
        repo.diagnoseAttempt(
          item: _currentItem,
          answer: _answerController.text.trim(),
          score: checked,
          attemptId: attemptId,
        ),
      );
      unawaited(
        const StudyAssignmentsRepository().syncQuiet(_currentItem.language),
      );
    } catch (_) {}
    _scores.add(checked.score);
    if (!mounted) return;
    final finished = _index + 1 >= widget.items.length;
    if (finished && widget.calibrated) {
      unawaited(
        const StudyAssignmentsRepository().completeDictationFocus(
          language: _currentItem.language,
          focusTags: widget.focusTags,
          completedCount: widget.items.length,
        ),
      );
    }
    setState(() {
      _saving = false;
      _index += 1;
      _checked = null;
      _reinforce = null;
      _retriedAlmost = false;
      _answerController.clear();
      _audioError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.items.length) {
      final average = _scores.isEmpty
          ? 0
          : (_scores.reduce((a, b) => a + b) / _scores.length).round();
      return Scaffold(
        appBar: AppBar(title: const Text('Ditado')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sessão concluída! Nota média: $average%\n(${_scores.length} frase(s))',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final checked = _checked;
    final almost =
        checked != null &&
        !_retriedAlmost &&
        isDictationAlmostCorrect(checked.score);

    return Scaffold(
      appBar: AppBar(title: Text('${_index + 1} / ${widget.items.length}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: _index / widget.items.length),
              const SizedBox(height: 24),
              Center(
                child: FilledButton.icon(
                  onPressed: _loadingAudio ? null : _playAudio,
                  icon: _loadingAudio
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Ouvir'),
                ),
              ),
              if (_audioError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _audioError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _answerController,
                enabled: checked == null,
                decoration: const InputDecoration(
                  labelText: 'Digite o que você ouviu',
                ),
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => _check(),
              ),
              const SizedBox(height: 16),
              if (checked == null)
                FilledButton(
                  onPressed:
                      (_checking || _answerController.text.trim().isEmpty)
                      ? null
                      : _check,
                  child: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verificar'),
                )
              else if (almost) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${checked.score}% — quase certo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'A frase ainda não é revelada. Tente de novo ou continue.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _retryAlmost,
                  child: const Text('Tentar de novo'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _check(forceFinal: true),
                  child: const Text('Continuar mesmo assim'),
                ),
              ] else ...[
                _ScoreCard(result: checked, expected: _currentItem.promptText),
                if (_loadingReinforce) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_reinforce != null) ...[
                  const SizedBox(height: 12),
                  _ReinforceCard(result: _reinforce!),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _saveAndNext,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _index + 1 < widget.items.length
                              ? 'Próxima'
                              : 'Concluir',
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result, required this.expected});

  final DictationGradingResult result;
  final String expected;

  @override
  Widget build(BuildContext context) {
    final color = result.score >= 80
        ? Colors.green
        : result.score >= 50
        ? Colors.orange
        : Theme.of(context).colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${result.score}%',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: color),
                ),
                if (result.source == 'hybrid') ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text('Frase correta: $expected'),
            if (result.feedback != null) ...[
              const SizedBox(height: 8),
              Text(
                result.feedback!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (result.mistakes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'O que ajustar:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              for (final mistake in result.mistakes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    mistake.note ??
                        (mistake.answer.isEmpty
                            ? 'Faltou: "${mistake.expected}"'
                            : mistake.expected.isEmpty
                            ? 'Sobrou: "${mistake.answer}"'
                            : '"${mistake.answer}" → "${mistake.expected}"'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReinforceCard extends StatefulWidget {
  const _ReinforceCard({required this.result});

  final DictationReinforceResult result;

  @override
  State<_ReinforceCard> createState() => _ReinforceCardState();
}

class _ReinforceCardState extends State<_ReinforceCard> {
  final _drillController = TextEditingController();
  bool? _drillOk;

  @override
  void dispose() {
    _drillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drill = widget.result.firstDrill;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.result.headline.isEmpty
                        ? 'Reforço'
                        : widget.result.headline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(widget.result.explanation),
            if (widget.result.rule.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Regra: ${widget.result.rule}'),
            ],
            if (drill != null) ...[
              const SizedBox(height: 12),
              if (drill.example.isNotEmpty) Text(drill.example),
              if (drill.prompt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  drill.prompt,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
              if (drill.hint.isNotEmpty) Text('Dica: ${drill.hint}'),
              const SizedBox(height: 8),
              TextField(
                controller: _drillController,
                enabled: _drillOk == null,
                decoration: const InputDecoration(labelText: 'Complete'),
              ),
              const SizedBox(height: 8),
              if (_drillOk == null)
                OutlinedButton(
                  onPressed: () {
                    final expected = drill.expected.trim().toLowerCase();
                    final got = _drillController.text.trim().toLowerCase();
                    setState(
                      () => _drillOk = expected.isEmpty || got == expected,
                    );
                  },
                  child: const Text('Checar'),
                )
              else
                Text(
                  _drillOk! ? 'Certo!' : 'Resposta: ${drill.expected}',
                  style: TextStyle(
                    color: _drillOk!
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
