import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../dictation/models/dictation_score.dart';
import 'models/placement_item.dart';
import 'models/placement_result.dart';
import 'models/placement_scoring.dart';
import 'placement_controller.dart';
import 'placement_repository.dart';

const Map<String, String> _dimensionLabels = {
  'vocab': 'Vocabulário',
  'grammar': 'Gramática',
  'listening': 'Compreensão oral',
  'production': 'Produção',
  'dictation': 'Ditado',
};

String _dimensionLabel(PlacementDimension dimension) => _dimensionLabels[dimension.name] ?? dimension.name;

/// Uma pergunta já respondida, guardada só em memória do lado do cliente pra
/// montar o gabarito ao final — espelha `PlacementReviewEntry` do web.
class _ReviewEntry {
  const _ReviewEntry({
    required this.index,
    required this.dimension,
    required this.cefr,
    required this.prompt,
    this.options,
    this.chosenOption,
    this.correctOption,
    this.correct,
    this.answer,
    this.modelText,
    this.dictationScore,
    this.needsWork,
  });

  final int index;
  final PlacementDimension dimension;
  final String cefr;
  final String prompt;

  // MCQ
  final Map<String, String>? options;
  final String? chosenOption;
  final String? correctOption;
  final bool? correct;

  // Free text
  final String? answer;
  final String? modelText;
  final int? dictationScore;
  final bool? needsWork;

  bool get isMcq => options != null;
  bool get isOk => isMcq ? (correct ?? false) : !(needsWork ?? false);
}

/// Espelha as fases "testing"/"result" de `src/pages/student/PlacementPage.tsx`.
/// Cada pergunta é: responder (MCQ) ou enviar texto livre (tradução, ditado,
/// produção livre) → feedback local (sem revelar o gabarito de MCQ durante a
/// sessão) → "Próxima pergunta" → repete até o servidor sinalizar `completed`.
class PlacementSessionPage extends ConsumerStatefulWidget {
  const PlacementSessionPage({super.key, required this.initial});

  final PlacementStepResult initial;

  @override
  ConsumerState<PlacementSessionPage> createState() => _PlacementSessionPageState();
}

class _PlacementSessionPageState extends ConsumerState<PlacementSessionPage> {
  final _answerController = TextEditingController();
  final _player = AudioPlayer();
  final Map<String, String> _audioUrlCache = {};
  final List<_ReviewEntry> _reviewLog = [];

  late PlacementItem _item;
  late String _sessionId;
  late String _language;
  int _questionNumber = 1;
  String? _currentCefr;

  bool _loading = false;
  bool _loadingAudio = false;
  String? _audioError;
  String? _error;

  bool _showingFeedback = false;
  String? _chosenOption;
  bool? _lastCorrect;
  bool _freeTextSubmitted = false;
  bool _freeTextNeedsWork = false;
  int? _dictationScore;
  String? _dictationExpected;
  PlacementProductionGrade? _productionGrade;
  PlacementStepResult? _pendingResult;

  bool _resultPhase = false;
  String _resultCefr = 'A1';
  Map<String, PlacementDimensionScore> _resultDimensionScores = const {};

  @override
  void initState() {
    super.initState();
    _item = widget.initial.item!;
    _sessionId = widget.initial.sessionId;
    _language = widget.initial.language;
    _currentCefr = widget.initial.currentCefr ?? _item.cefr;
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
      var url = _audioUrlCache[_item.id];
      if (url == null) {
        final text = (_item.audioText?.isNotEmpty == true ? _item.audioText : _item.prompt) ?? '';
        url = await ref.read(placementRepositoryProvider).fetchAudioUrl(text: text, language: _item.language);
        if (url != null) _audioUrlCache[_item.id] = url;
      }
      if (url == null) {
        setState(() => _audioError = 'Não foi possível gerar o áudio.');
        return;
      }
      await _player.setUrl(url);
      await _player.seek(Duration.zero);
      // `play()` só resolve quando a faixa termina (ou é interrompida) —
      // não podemos aguardar aqui ou o botão fica travado até o fim do áudio.
      unawaited(_player.play());
    } catch (_) {
      if (mounted) setState(() => _audioError = 'Não foi possível tocar o áudio.');
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _answerMcq(String option) async {
    if (_loading || _showingFeedback) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(placementRepositoryProvider).submitAnswer(
            sessionId: _sessionId,
            itemId: _item.id,
            chosenOption: option,
            fallbackLanguage: _language,
          );
      _reviewLog.add(_ReviewEntry(
        index: _questionNumber,
        dimension: _item.dimension,
        cefr: _item.cefr,
        prompt: _item.prompt,
        options: _item.options,
        chosenOption: option,
        correctOption: result.correctOption,
        correct: result.correct ?? false,
      ));
      setState(() {
        _chosenOption = option;
        _lastCorrect = result.correct ?? false;
        _showingFeedback = true;
        _pendingResult = result;
        _currentCefr = result.currentCefr ?? result.resultCefr ?? _currentCefr;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível enviar a resposta. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitFreeText() async {
    if (_loading || _showingFeedback) return;
    final text = _answerController.text.trim();
    if (text.length < 2) {
      setState(() => _error = 'Escreva pelo menos algumas palavras.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(placementRepositoryProvider);
      String? productionCefr;
      PlacementProductionGrade? grade;
      String expected = '';
      int? score;

      if (_item.isDictation) {
        expected = (_item.audioText?.isNotEmpty == true ? _item.audioText! : _item.prompt).trim();
        final local = scoreDictationAnswer(expected, text);
        score = local.score;
        productionCefr = dictationScoreToCefr(local.score, _item.cefr);
      } else {
        try {
          grade = await repo.gradeProduction(
            answer: text,
            language: _item.language,
            promptCefr: _item.cefr,
            sourcePt: _item.isFreeWriting ? null : _item.prompt,
            freeWriting: _item.isFreeWriting,
            taskPrompt: _item.isFreeWriting ? _item.prompt : null,
          );
          productionCefr = grade?.productionCefr;
        } catch (_) {
          // Segue sem nota da IA — o RPC trata productionCefr nulo como incorreto.
        }
      }

      final needsWork = placementProductionNeedsWork(
        showModel: grade?.showModel ?? false,
        productionCefr: productionCefr,
        promptCefr: _item.cefr,
        dictationScore: score,
        answer: text,
        sourcePt: _item.isDictation || _item.isFreeWriting ? null : _item.prompt,
      );

      final submitCefr = _item.isDictation
          ? productionCefr
          : placementSoftPassCefr(productionCefr: productionCefr, itemCefr: _item.cefr, needsWork: needsWork);

      final result = await repo.submitProduction(
        sessionId: _sessionId,
        itemId: _item.id,
        freeText: text,
        fallbackLanguage: _language,
        productionCefr: submitCefr,
      );

      _reviewLog.add(_ReviewEntry(
        index: _questionNumber,
        dimension: _item.dimension,
        cefr: _item.cefr,
        prompt: _item.isDictation ? '' : _item.prompt,
        answer: text,
        modelText: expected.isNotEmpty ? expected : grade?.modelTranslation,
        dictationScore: score,
        needsWork: needsWork,
      ));

      setState(() {
        _dictationScore = score;
        _dictationExpected = expected.isNotEmpty ? expected : null;
        _productionGrade = grade;
        _freeTextNeedsWork = needsWork;
        _freeTextSubmitted = true;
        _showingFeedback = true;
        _pendingResult = result;
        _currentCefr = result.currentCefr ?? result.resultCefr ?? _currentCefr;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível enviar a resposta. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continue() {
    final result = _pendingResult;
    if (result == null) return;
    if (result.completed) {
      setState(() {
        _resultPhase = true;
        _resultCefr = result.resultCefr ?? _currentCefr ?? 'A1';
        _resultDimensionScores = result.dimensionScores;
      });
      return;
    }
    _player.pause();
    setState(() {
      _item = result.item!;
      _questionNumber += 1;
      _currentCefr = result.currentCefr;
      _chosenOption = null;
      _lastCorrect = null;
      _freeTextSubmitted = false;
      _freeTextNeedsWork = false;
      _dictationScore = null;
      _dictationExpected = null;
      _productionGrade = null;
      _pendingResult = null;
      _showingFeedback = false;
      _answerController.clear();
      _audioError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resultPhase) return _ResultView(cefr: _resultCefr, dimensionScores: _resultDimensionScores, reviewLog: _reviewLog);

    return Scaffold(
      appBar: AppBar(title: Text('Pergunta $_questionNumber · ${_currentCefr ?? _item.cefr}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Chip(label: Text(_dimensionLabel(_item.dimension))),
              const SizedBox(height: 16),
              Text(_item.prompt, style: Theme.of(context).textTheme.titleMedium),
              if (_item.needsAudio) ...[
                const SizedBox(height: 16),
                Center(
                  child: FilledButton.icon(
                    onPressed: _loadingAudio ? null : _playAudio,
                    icon: _loadingAudio
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: const Text('Ouvir áudio'),
                  ),
                ),
                if (_audioError != null) ...[
                  const SizedBox(height: 8),
                  Text(_audioError!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
                ],
              ],
              const SizedBox(height: 24),
              if (_item.isFreeText) ..._buildFreeTextInput() else ..._buildMcqOptions(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (_showingFeedback) ...[
                const SizedBox(height: 16),
                _buildFeedbackCard(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMcqOptions() {
    const keys = ['A', 'B', 'C', 'D'];
    return [
      for (final key in keys)
        if ((_item.options[key] ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: (_loading || _showingFeedback) ? null : () => _answerMcq(key),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                backgroundColor: _showingFeedback && key == _chosenOption
                    ? (_lastCorrect == true ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.1))
                    : null,
              ),
              child: Text('$key.  ${_item.options[key]}'),
            ),
          ),
    ];
  }

  List<Widget> _buildFreeTextInput() {
    return [
      TextField(
        controller: _answerController,
        enabled: !_showingFeedback,
        minLines: _item.isFreeWriting ? 4 : 2,
        maxLines: 6,
        maxLength: 800,
        decoration: InputDecoration(
          labelText: _item.isDictation
              ? 'Digite o que você ouviu'
              : _item.isFreeWriting
                  ? 'Escreva sua resposta'
                  : 'Digite sua tradução',
        ),
      ),
      if (!_showingFeedback) ...[
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loading ? null : _submitFreeText,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_item.isDictation ? 'Enviar ditado' : 'Enviar'),
        ),
      ],
    ];
  }

  Widget _buildFeedbackCard(BuildContext context) {
    final bool ok = _freeTextSubmitted ? !_freeTextNeedsWork : (_lastCorrect ?? false);
    final color = ok ? Colors.green : Theme.of(context).colorScheme.error;
    final showModel = _freeTextSubmitted && _freeTextNeedsWork && _productionGrade?.modelTranslation.isNotEmpty == true;

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_circle : Icons.cancel, color: color),
                const SizedBox(width: 8),
                Text(
                  _freeTextSubmitted
                      ? (ok ? 'Boa produção' : 'Resposta incompleta ou com erros')
                      : (ok ? 'Resposta correta' : 'Resposta incorreta'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_dictationExpected != null) ...[
              Text('Pontuação do ditado: ${_dictationScore ?? 0}%'),
              const SizedBox(height: 4),
              Text('Frase correta: $_dictationExpected', style: const TextStyle(fontWeight: FontWeight.w600)),
            ] else if (showModel) ...[
              Text('Forma natural: ${_productionGrade!.modelTranslation}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ] else if (!_freeTextSubmitted) ...[
              Text(ok ? 'Muito bem. Vamos um pouco mais longe.' : 'Ajustamos a dificuldade para a próxima pergunta.'),
            ] else ...[
              Text(ok ? 'Sua resposta está sólida neste nível. Seguimos.' : 'Há erros ou trechos incompletos nesta resposta. Revise e siga para a próxima.'),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _continue,
              child: Text(_pendingResult?.completed == true ? 'Ver meu nível' : 'Próxima pergunta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.cefr, required this.dimensionScores, required this.reviewLog});

  final String cefr;
  final Map<String, PlacementDimensionScore> dimensionScores;
  final List<_ReviewEntry> reviewLog;

  @override
  Widget build(BuildContext context) {
    final productionTotal = (dimensionScores['production']?.total ?? 0) + (dimensionScores['dictation']?.total ?? 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.emoji_events_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('Seu nível: $cefr', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Pronto pra estudar com conteúdos alinhados a esse nível.'),
            const SizedBox(height: 24),
            if (dimensionScores.isNotEmpty) ...[
              Text('Desempenho por dimensão', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final dim in ['vocab', 'grammar', 'listening'])
                if (dimensionScores[dim] != null) _DimensionBar(label: _dimensionLabels[dim]!, score: dimensionScores[dim]!),
              if (productionTotal > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$productionTotal resposta(s) de produção — a parte ativa pode limitar o nível final.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
            ],
            if (reviewLog.isNotEmpty) ...[
              Text('Gabarito do teste', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final entry in reviewLog) _ReviewTile(entry: entry),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionBar extends StatelessWidget {
  const _DimensionBar({required this.label, required this.score});

  final String label;
  final PlacementDimensionScore score;

  @override
  Widget build(BuildContext context) {
    final pct = (score.ratio * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text('${score.correct}/${score.total} ($pct%)', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: score.ratio.clamp(0, 1), minHeight: 6),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.entry});

  final _ReviewEntry entry;

  @override
  Widget build(BuildContext context) {
    final okColor = entry.isOk ? Colors.green : Theme.of(context).colorScheme.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Pergunta ${entry.index} · ${_dimensionLabel(entry.dimension)} · ${entry.cefr}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(entry.isOk ? 'Acertou' : 'Errou', style: TextStyle(color: okColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            if (entry.prompt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(entry.prompt, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: 8),
            if (entry.isMcq)
              for (final key in ['A', 'B', 'C', 'D'])
                if ((entry.options![key] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$key. ${entry.options![key]}'
                      '${key == entry.chosenOption ? '  (sua resposta)' : ''}',
                      style: TextStyle(
                        color: key == entry.correctOption
                            ? Colors.green
                            : key == entry.chosenOption
                                ? Theme.of(context).colorScheme.error
                                : null,
                      ),
                    ),
                  )
            else ...[
              Text('Sua resposta: ${entry.answer}'),
              if (entry.dictationScore != null) Text('Pontuação: ${entry.dictationScore}%', style: Theme.of(context).textTheme.bodySmall),
              if (entry.modelText != null)
                Text(
                  entry.dictationScore != null ? 'Frase correta: ${entry.modelText}' : 'Forma natural: ${entry.modelText}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
