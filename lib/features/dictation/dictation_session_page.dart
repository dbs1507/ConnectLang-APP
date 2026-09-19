import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../design_system/components/feedback/lia_mark.dart';
import '../../design_system/components/progress/lesson_progress.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../library/models/inline_translation.dart';
import '../notebook/notebook_controller.dart';
import '../study_coach/study_assignments_repository.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import '../vocabulary/vocabulary_controller.dart';
import '../vocabulary/vocabulary_repository.dart';
import 'dictation_controller.dart';
import 'models/dictation_item.dart';
import 'models/dictation_next_result.dart';
import 'models/dictation_score.dart';

const _cardRadius = BorderRadius.all(Radius.circular(16));
const _fieldRadius = BorderRadius.all(Radius.circular(12));

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

  StreamSubscription<PlayerState>? _playerSub;
  String? _loadedItemId;
  bool _playing = false;
  bool _hasPlayed = false;

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

  double _playbackRate = 1;
  var _loop = false;

  final Map<String, String> _translations = {};
  bool _translationVisible = false;
  bool _translatingPrompt = false;
  String? _translationError;
  late String _translationTargetLang =
      widget.items.isNotEmpty && widget.items.first.language == 'PT'
      ? 'EN'
      : 'PT';

  String? _selectedText;

  DictationItem get _currentItem => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _answerController.addListener(() => setState(() {}));
    _playerSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state.playing &&
            (state.processingState != ProcessingState.completed || _loop);
      });
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _answerController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _resetPlayer() async {
    try {
      await _player.stop();
    } catch (_) {}
    _loadedItemId = null;
    _playing = false;
    _hasPlayed = false;
  }

  Future<void> _playAudio() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_loadedItemId == _currentItem.id && _player.audioSource != null) {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _applyLoopMode();
      unawaited(_player.play());
      setState(() => _hasPlayed = true);
      return;
    }
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
      _loadedItemId = _currentItem.id;
      await _player.seek(Duration.zero);
      try {
        await _player.setSpeed(_playbackRate);
      } catch (_) {}
      await _applyLoopMode();
      unawaited(_player.play());
      if (mounted) setState(() => _hasPlayed = true);
    } catch (e, st) {
      debugPrint('DICTATION_AUDIO_ERROR: $e\n$st');
      if (mounted) {
        setState(() => _audioError = 'Não foi possível tocar o áudio.');
      }
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _applyLoopMode() async {
    try {
      await _player.setLoopMode(_loop ? LoopMode.one : LoopMode.off);
    } catch (_) {}
  }

  Future<void> _toggleLoop() async {
    setState(() => _loop = !_loop);
    await _applyLoopMode();
  }

  Future<void> _nudgeRate(double delta) async {
    final next = (_playbackRate + delta).clamp(0.5, 1.75);
    setState(() => _playbackRate = double.parse(next.toStringAsFixed(2)));
    try {
      await _player.setSpeed(_playbackRate);
    } catch (_) {}
  }

  String _translationKey(String itemId) =>
      '$itemId:${translationLocaleFromAppLanguage(_translationTargetLang)}';

  Future<void> _toggleTranslation() async {
    if (_translationVisible) {
      setState(() => _translationVisible = false);
      return;
    }
    setState(() {
      _translationVisible = true;
      _translationError = null;
    });
    await _loadTranslation();
  }

  void _onTranslationLanguageSelected(String lang) {
    if (lang == _translationTargetLang) return;
    final nextKey =
        '${_currentItem.id}:${translationLocaleFromAppLanguage(lang)}';
    setState(() {
      _translationTargetLang = lang;
      _translationError = null;
      if (!_translations.containsKey(nextKey)) {
        _translatingPrompt = true;
      }
    });
    if (_translationVisible) unawaited(_loadTranslation());
  }

  Future<void> _loadTranslation() async {
    final item = _currentItem;
    final key = _translationKey(item.id);
    if (_translations.containsKey(key)) return;
    final targetIsPt = _translationTargetLang == 'PT';
    final fallback = item.promptTranslation?.trim();
    if (targetIsPt && fallback != null && fallback.isNotEmpty) {
      setState(() => _translations[key] = fallback);
      return;
    }
    setState(() {
      _translatingPrompt = true;
      _translationError = null;
    });
    final translated = await ref
        .read(dictationRepositoryProvider)
        .translatePrompt(
          text: item.promptText,
          language: item.language,
          targetLocale: translationLocaleFromAppLanguage(_translationTargetLang),
        );
    if (!mounted || item.id != _currentItem.id) return;
    setState(() {
      _translatingPrompt = false;
      if (translated == null) {
        _translationError = 'Não foi possível traduzir agora.';
      } else {
        _translations[key] = translated;
      }
    });
  }

  Future<void> _restartSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar sessão?'),
        content: const Text('Seu progresso nesta sessão será perdido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _resetPlayer();
    if (!mounted) return;
    setState(() {
      _index = 0;
      _scores.clear();
      _checked = null;
      _reinforce = null;
      _retriedAlmost = false;
      _translationVisible = false;
      _translationError = null;
      _selectedText = null;
      _answerController.clear();
      _audioError = null;
    });
  }

  Future<void> _openSaveVocabSheet(String term) async {
    final item = _currentItem;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SaveWordFromDictationSheet(
        term: term,
        language: item.language,
        surroundingText: item.promptText,
      ),
    );
    if (mounted) setState(() => _selectedText = null);
  }

  Future<void> _check() async {
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
        !_retriedAlmost && isDictationAlmostCorrect(merged.score);
    setState(() {
      _checked = merged;
      _checking = false;
      _translationVisible = true;
    });
    unawaited(_loadTranslation());
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

  void _continueAlmost() {
    final checked = _checked;
    if (checked == null) return;
    setState(() {
      _retriedAlmost = true;
      _translationVisible = true;
    });
    unawaited(_loadTranslation());
    if (checked.mistakes.isNotEmpty || checked.score < 100) {
      unawaited(_loadReinforce(checked));
    }
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
    await _resetPlayer();
    setState(() {
      _saving = false;
      _index += 1;
      _checked = null;
      _reinforce = null;
      _retriedAlmost = false;
      _translationError = null;
      _selectedText = null;
      _answerController.clear();
      _audioError = null;
    });
    if (_translationVisible && _index < widget.items.length) {
      unawaited(_loadTranslation());
    }
  }

  InputDecoration get _answerDecoration {
    return InputDecoration(
      hintText: 'Digite o que você ouviu',
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.items.length) {
      return _SessionDone(
        average: _scores.isEmpty
            ? 0
            : (_scores.reduce((a, b) => a + b) / _scores.length).round(),
        count: _scores.length,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    final checked = _checked;
    final almost =
        checked != null &&
        !_retriedAlmost &&
        isDictationAlmostCorrect(checked.score);
    final canCheck =
        !_checking && _answerController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundMuted,
      appBar: AppBar(
        title: const Text('Ditado'),
        backgroundColor: AppColors.backgroundMuted,
        actions: [
          IconButton(
            tooltip: 'Reiniciar',
            onPressed: _restartSession,
            icon: const Icon(LucideIcons.refresh_ccw),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LessonProgress(
                      current: _index + 1,
                      total: widget.items.length,
                      label: 'Frase ${_index + 1} de ${widget.items.length}',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _ListenCard(
                      loading: _loadingAudio,
                      playing: _playing,
                      hasPlayed: _hasPlayed,
                      looping: _loop,
                      error: _audioError,
                      onPlay: _playAudio,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AudioControlsRow(
                      playbackRate: _playbackRate,
                      onNudgeRate: _nudgeRate,
                      looping: _loop,
                      onToggleLoop: _toggleLoop,
                      translationVisible: _translationVisible,
                      onToggleTranslation: _toggleTranslation,
                    ),
                    if (_translationVisible) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _TranslationPanel(
                        loading: _translatingPrompt,
                        translation:
                            _translations[_translationKey(_currentItem.id)],
                        error: _translationError,
                        sourceLanguage: _currentItem.language,
                        targetLanguage: _translationTargetLang,
                        onLanguageSelected: _onTranslationLanguageSelected,
                        onRetry: _loadTranslation,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _answerController,
                      enabled: checked == null,
                      decoration: _answerDecoration,
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.done,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.heading,
                      ),
                      onSubmitted: (_) {
                        if (canCheck) unawaited(_check());
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_answerController.text.length} caracteres',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (checked != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      if (almost)
                        const _AlmostCard()
                      else ...[
                        _ScoreCard(
                          result: checked,
                          expected: _currentItem.promptText,
                          onSelectionChanged: (text) {
                            setState(() => _selectedText = text);
                          },
                        ),
                        if (_selectedText != null &&
                            _selectedText!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _SaveSelectionChip(
                            text: _selectedText!.trim(),
                            onSave: () => _openSaveVocabSheet(
                              _selectedText!.trim(),
                            ),
                          ),
                        ],
                        if (_loadingReinforce) ...[
                          const SizedBox(height: AppSpacing.md),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_reinforce != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _ReinforceCard(result: _reinforce!),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _SessionFooter(
              child: checked == null
                  ? FilledButton(
                      onPressed: canCheck ? _check : null,
                      child: _checking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Verificar'),
                    )
                  : almost
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: _retryAlmost,
                          child: const Text('Tentar de novo'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: _continueAlmost,
                          child: const Text('Continuar mesmo assim'),
                        ),
                      ],
                    )
                  : FilledButton(
                      onPressed: _saving ? null : _saveAndNext,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _index + 1 < widget.items.length
                                  ? 'Próxima'
                                  : 'Concluir',
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionFooter extends StatelessWidget {
  const _SessionFooter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _ListenCard extends StatelessWidget {
  const _ListenCard({
    required this.loading,
    required this.playing,
    required this.hasPlayed,
    required this.looping,
    required this.onPlay,
    this.error,
  });

  final bool loading;
  final bool playing;
  final bool hasPlayed;
  final bool looping;
  final VoidCallback onPlay;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = loading
        ? 'Preparando o áudio…'
        : playing
        ? (looping ? 'Ouvindo em loop…' : 'Ouvindo…')
        : hasPlayed
        ? 'Ouvir de novo'
        : 'Ouvir a frase';

    return Material(
      color: AppColors.background,
      borderRadius: _cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onPlay,
        child: Ink(
          decoration: const BoxDecoration(
            borderRadius: _cardRadius,
            border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: playing
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(22),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          playing ? LucideIcons.pause : LucideIcons.play,
                          size: 28,
                          color: playing
                              ? Colors.white
                              : AppColors.primary,
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.heading,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    error!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.destructive,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioControlsRow extends StatelessWidget {
  const _AudioControlsRow({
    required this.playbackRate,
    required this.onNudgeRate,
    required this.looping,
    required this.onToggleLoop,
    required this.translationVisible,
    required this.onToggleTranslation,
  });

  final double playbackRate;
  final ValueChanged<double> onNudgeRate;
  final bool looping;
  final VoidCallback onToggleLoop;
  final bool translationVisible;
  final VoidCallback onToggleTranslation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          tooltip: 'Mais devagar',
          onPressed: playbackRate <= 0.5 ? null : () => onNudgeRate(-0.1),
          icon: const Icon(LucideIcons.minus, size: 18),
        ),
        Text(
          '${playbackRate.toStringAsFixed(2)}x',
          style: textTheme.labelMedium?.copyWith(color: AppColors.heading),
        ),
        IconButton(
          tooltip: 'Mais rápido',
          onPressed: playbackRate >= 1.75 ? null : () => onNudgeRate(0.1),
          icon: const Icon(LucideIcons.plus, size: 18),
        ),
        IconButton(
          tooltip: looping ? 'Parar loop' : 'Ouvir em loop',
          onPressed: onToggleLoop,
          style: IconButton.styleFrom(
            backgroundColor: looping
                ? AppColors.primary
                : Colors.transparent,
            foregroundColor: looping ? Colors.white : AppColors.navText,
          ),
          icon: Icon(
            LucideIcons.infinity,
            size: 18,
            color: looping ? Colors.white : AppColors.navText,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onToggleTranslation,
              icon: const Icon(LucideIcons.languages, size: 18),
              label: Text(
                translationVisible ? 'Ocultar tradução' : 'Ver tradução',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TranslationPanel extends StatelessWidget {
  const _TranslationPanel({
    required this.loading,
    required this.translation,
    required this.error,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onLanguageSelected,
    required this.onRetry,
  });

  final bool loading;
  final String? translation;
  final String? error;
  final String sourceLanguage;
  final String targetLanguage;
  final ValueChanged<String> onLanguageSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: _cardRadius,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Traduzir para',
                  style: textTheme.bodySmall,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Idioma da tradução',
                  onSelected: onLanguageSelected,
                  itemBuilder: (context) => [
                    for (final entry in taughtLanguages.entries)
                      if (entry.key != sourceLanguage)
                        PopupMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        taughtLanguages[targetLanguage] ?? targetLanguage,
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.heading,
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevron_down,
                        size: 18,
                        color: AppColors.foreground,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (loading)
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (error != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              )
            else
              Text(
                translation ?? '',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.heading,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaveSelectionChip extends StatelessWidget {
  const _SaveSelectionChip({required this.text, required this.onSave});

  final String text;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: _cardRadius,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '"$text"',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.heading,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: onSave,
              icon: const Icon(LucideIcons.book_plus, size: 16),
              label: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveWordFromDictationSheet extends ConsumerStatefulWidget {
  const _SaveWordFromDictationSheet({
    required this.term,
    required this.language,
    required this.surroundingText,
  });

  final String term;
  final String language;
  final String surroundingText;

  @override
  ConsumerState<_SaveWordFromDictationSheet> createState() =>
      _SaveWordFromDictationSheetState();
}

class _SaveWordFromDictationSheetState
    extends ConsumerState<_SaveWordFromDictationSheet> {
  late final _termController = TextEditingController(text: widget.term);
  final _translationController = TextEditingController();
  final _contextController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final VocabEntryKind _entryKind = VocabEntryKind.infer(widget.term);
  String? _partOfSpeech;
  bool _enriching = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_enrich());
  }

  @override
  void dispose() {
    _termController.dispose();
    _translationController.dispose();
    _contextController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _enrich() async {
    final term = _termController.text.trim();
    if (term.isEmpty) return;
    setState(() {
      _enriching = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(vocabularyRepositoryProvider)
          .enrichTerm(
            term: term,
            language: widget.language,
            entryKind: _entryKind,
            surroundingText: widget.surroundingText,
          );
      if (result == null) {
        setState(
          () => _error = 'Não foi possível preencher com IA. Tente de novo.',
        );
        return;
      }
      setState(() {
        if (result.translation.isNotEmpty) {
          _translationController.text = result.translation;
        }
        if (result.example.isNotEmpty &&
            _contextController.text.trim().isEmpty) {
          _contextController.text = result.example;
        }
        if (result.context.isNotEmpty &&
            _contextController.text.trim().isEmpty) {
          _contextController.text = result.context;
        }
        if (result.description.isNotEmpty) {
          _descriptionController.text = result.description;
        }
        _partOfSpeech = result.partOfSpeech;
      });
    } catch (_) {
      setState(
        () => _error = 'Não foi possível preencher com IA. Tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _enriching = false);
    }
  }

  Future<void> _submit() async {
    final term = _termController.text.trim();
    final translation = _translationController.text.trim();
    final contextText = _contextController.text.trim();
    final description = _descriptionController.text.trim();
    if (term.isEmpty ||
        translation.isEmpty ||
        contextText.isEmpty ||
        description.isEmpty) {
      setState(
        () => _error = 'Preencha trecho, tradução, contexto e descrição.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(vocabularyControllerProvider.notifier)
          .addFromText(
            term: term,
            translation: translation,
            language: widget.language,
            source: 'dictation',
            context: contextText,
            description: description,
            entryKind: _entryKind,
            example: contextText,
            partOfSpeech: _partOfSpeech,
            captureSurface: term,
          );
      if (mounted) Navigator.of(context).pop();
    } on DuplicateVocabularyTermException {
      setState(() => _error = 'Esse termo já está na sua lista.');
    } catch (_) {
      setState(() => _error = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Salvar no vocabulário',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _termController,
              decoration: InputDecoration(
                labelText: _entryKind == VocabEntryKind.sentence
                    ? 'Frase ou expressão'
                    : 'Palavra',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _enriching ? null : _enrich,
              icon: _enriching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.astroid, size: 18),
              label: const Text('Preencher com IA'),
            ),
            if (_partOfSpeech != null) ...[
              const SizedBox(height: 8),
              Text(
                'Classe: $_partOfSpeech',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _translationController,
              decoration: const InputDecoration(labelText: 'Tradução'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contextController,
              decoration: const InputDecoration(labelText: 'Contexto'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição'),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlmostCard extends StatelessWidget {
  const _AlmostCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: _cardRadius,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quase certo',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A frase ainda não é revelada. Tente de novo ou continue.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.result,
    required this.expected,
    this.onSelectionChanged,
  });

  final DictationGradingResult result;
  final String expected;
  final ValueChanged<String?>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = result.score >= 80
        ? AppColors.success
        : result.score >= 50
        ? AppColors.terracotta
        : AppColors.destructive;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: _cardRadius,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${result.score}%',
                  style: textTheme.displaySmall?.copyWith(color: color),
                ),
                if (result.source == 'hybrid') ...[
                  const SizedBox(width: AppSpacing.sm),
                  const LiaBurstIcon(size: 16),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Frase correta', style: textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            SelectionArea(
              onSelectionChanged: (content) =>
                  onSelectionChanged?.call(content?.plainText),
              child: Text(expected, style: textTheme.headlineSmall),
            ),
            if (result.feedback != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(result.feedback!, style: textTheme.bodyMedium),
            ],
            if (result.mistakes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'O que ajustar',
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final mistake in result.mistakes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    _mistakeLabel(mistake),
                    style: textTheme.bodyMedium,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _mistakeLabel(DictationMistake mistake) {
  final expected = mistake.expected.trim();
  final answer = mistake.answer.trim();
  if (answer.isEmpty && expected.isNotEmpty) {
    return 'Faltou "$expected"';
  }
  if (expected.isEmpty && answer.isNotEmpty) {
    return 'Entrou a mais: "$answer"';
  }
  if (expected.isNotEmpty && answer.isNotEmpty) {
    return '"$answer" → "$expected"';
  }
  final note = mistake.note?.trim();
  if (note != null && note.isNotEmpty) return note;
  return 'Ajuste esta parte da frase.';
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
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: _cardRadius,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LiaBurstIcon(size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.result.headline.isEmpty
                        ? 'Reforço'
                        : widget.result.headline,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.heading,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(widget.result.explanation, style: textTheme.bodyMedium),
            if (widget.result.rule.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Regra: ${widget.result.rule}',
                style: textTheme.bodyMedium,
              ),
            ],
            if (drill != null) ...[
              const SizedBox(height: AppSpacing.lg),
              if (drill.example.isNotEmpty)
                Text(drill.example, style: textTheme.bodyMedium),
              if (drill.prompt.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  drill.prompt,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.heading,
                  ),
                ),
              ],
              if (drill.hint.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('Dica: ${drill.hint}', style: textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _drillController,
                enabled: _drillOk == null,
                decoration: const InputDecoration(
                  hintText: 'Complete',
                  border: OutlineInputBorder(borderRadius: _fieldRadius),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: _fieldRadius,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: _fieldRadius,
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
                  style: textTheme.titleSmall?.copyWith(
                    color: _drillOk! ? AppColors.success : AppColors.destructive,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionDone extends StatelessWidget {
  const _SessionDone({
    required this.average,
    required this.count,
    required this.onBack,
  });

  final int average;
  final int count;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.backgroundMuted,
      appBar: AppBar(
        title: const Text('Ditado'),
        backgroundColor: AppColors.backgroundMuted,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  LucideIcons.circle_check,
                  size: 32,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Sessão concluída', style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Nota média $average%  ·  $count frase${count == 1 ? '' : 's'}',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onBack,
                  child: const Text('Voltar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
