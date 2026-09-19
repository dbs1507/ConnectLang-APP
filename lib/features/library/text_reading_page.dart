import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../notebook/notebook_fab.dart';
import '../../design_system/components/cards/app_surface.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../../design_system/theme/app_typography.dart';
import '../vocabulary/models/vocab_category.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import '../vocabulary/vocabulary_controller.dart';
import '../vocabulary/vocabulary_repository.dart';
import 'library_controller.dart';
import 'library_repository.dart';
import 'models/inline_translation.dart';
import 'models/library_text.dart';
import 'models/text_question.dart';
import 'tappable_reading_text.dart';
import 'text_questions_page.dart';

class TextReadingPage extends ConsumerStatefulWidget {
  const TextReadingPage({super.key, required this.text});

  final LibraryText text;

  @override
  ConsumerState<TextReadingPage> createState() => _TextReadingPageState();
}

class _TextReadingPageState extends ConsumerState<TextReadingPage> {
  late LibraryText _text = widget.text;
  final _player = AudioPlayer();

  bool _loadingAudio = false;
  bool _isPlaying = false;
  String? _audioError;
  String _voiceGender = 'female';
  double _playbackRate = 1;

  TextQuestionSet? _questionSet;
  bool _loadingQuestions = true;
  bool _generatingQuestions = false;
  bool _savingPersonal = false;
  String? _ownedError;

  bool _showInlineTranslation = false;
  bool _translatingInline = false;
  late String _translationTargetLang = _text.language == 'PT' ? 'EN' : 'PT';
  final Map<String, String> _translations = {};
  final Set<String> _loadingKeys = {};
  String? _translationError;
  int _translationRequestId = 0;
  ReadingSelection? _readingSelection;

  @override
  void initState() {
    super.initState();
    _loadQuestionSet();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(
        () => _isPlaying =
            state.playing && state.processingState != ProcessingState.completed,
      );
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _closeReading() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final path = GoRouterState.of(context).uri.path;
    context.go(path.startsWith('/aluno') ? '/aluno/biblioteca' : '/estudo/biblioteca');
  }

  Future<void> _loadQuestionSet() async {
    setState(() => _loadingQuestions = true);
    try {
      final set = await ref
          .read(libraryRepositoryProvider)
          .fetchQuestionSet(_text.id, sourceType: _text.sourceKind.raw);
      if (!mounted) return;
      setState(() => _questionSet = set);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _resetAudio() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      unawaited(_player.play());
      return;
    }
    if (_player.processingState == ProcessingState.ready) {
      unawaited(_player.play());
      return;
    }

    setState(() {
      _loadingAudio = true;
      _audioError = null;
    });
    try {
      final chunks = await ref
          .read(libraryRepositoryProvider)
          .fetchTtsChunks(text: _text, voiceGender: _voiceGender);
      if (chunks.isEmpty) {
        setState(
          () => _audioError = 'Não foi possível gerar o áudio deste texto.',
        );
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final sources = <AudioSource>[];
      for (var i = 0; i < chunks.length; i++) {
        final base64Audio = chunks[i]['audioContentBase64'] as String? ?? '';
        if (base64Audio.isEmpty) continue;
        final bytes = base64Decode(base64Audio);
        final file = File(
          '${tempDir.path}/text_tts_${_text.sourceKind.raw}_${_text.id}_${_voiceGender}_$i.mp3',
        );
        await file.writeAsBytes(bytes, flush: true);
        sources.add(AudioSource.file(file.path));
      }
      if (sources.isEmpty) {
        setState(
          () => _audioError = 'Não foi possível gerar o áudio deste texto.',
        );
        return;
      }
      await _player.setAudioSources(sources);
      await _player.setSpeed(_playbackRate);
      unawaited(_player.play());
    } catch (e, st) {
      debugPrint('TEXT_TTS_ERROR: $e\n$st');
      if (mounted) {
        setState(() => _audioError = 'Não foi possível tocar o áudio.');
      }
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _changeVoice(String gender) async {
    if (gender == _voiceGender) return;
    await _resetAudio();
    setState(() => _voiceGender = gender);
  }

  Future<void> _nudgeRate(double delta) async {
    final next = (_playbackRate + delta).clamp(0.5, 1.75);
    setState(() => _playbackRate = double.parse(next.toStringAsFixed(2)));
    try {
      await _player.setSpeed(_playbackRate);
    } catch (_) {}
  }

  void _openQuestions() {
    final set = _questionSet;
    if (set == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextQuestionsPage(
          questionSet: set,
          language: _text.language,
          textId: _text.id,
        ),
      ),
    );
  }

  Future<void> _generateQuestions() async {
    setState(() {
      _generatingQuestions = true;
      _ownedError = null;
    });
    try {
      final set = await ref
          .read(libraryRepositoryProvider)
          .generateQuestions(
            sourceType: _text.sourceKind.raw,
            sourceId: _text.id,
          );
      if (!mounted) return;
      if (set == null) {
        setState(
          () => _ownedError = 'Não foi possível gerar as perguntas agora.',
        );
        return;
      }
      setState(() => _questionSet = set);
    } catch (_) {
      if (mounted) {
        setState(
          () => _ownedError = 'Não foi possível gerar as perguntas agora.',
        );
      }
    } finally {
      if (mounted) setState(() => _generatingQuestions = false);
    }
  }

  Future<void> _saveToPersonal() async {
    setState(() {
      _savingPersonal = true;
      _ownedError = null;
    });
    try {
      final personal = await ref
          .read(libraryControllerProvider.notifier)
          .saveTemporaryToPersonal(_text);
      if (!mounted) return;
      setState(() => _text = personal);
      await _resetAudio();
      await _loadQuestionSet();
    } on OwnedTextException catch (e) {
      setState(() {
        _ownedError = switch (e.code) {
          'personal_cap' =>
            'Você já tem $personalTextsSoftCap textos pessoais.',
          'already_saved' => 'Esse texto já foi salvo.',
          'expired' => 'Esse texto temporário já expirou.',
          _ => 'Não foi possível guardar o texto.',
        };
      });
    } catch (_) {
      setState(() => _ownedError = 'Não foi possível guardar o texto.');
    } finally {
      if (mounted) setState(() => _savingPersonal = false);
    }
  }

  String? get _selectedText => _readingSelection?.text;

  void _clearReadingSelection() {
    if (_readingSelection == null) return;
    setState(() => _readingSelection = null);
  }

  void _onTapReadingToken({
    required String scope,
    required int paragraphIndex,
    required int tokenIndex,
    required String paragraph,
  }) {
    final next = selectionFromTap(
      current: _readingSelection,
      scope: scope,
      paragraphIndex: paragraphIndex,
      tokenIndex: tokenIndex,
      tokens: tokenizeReadingParagraph(paragraph),
    );
    setState(() => _readingSelection = next);
  }

  void _onLongPressReadingToken({
    required String scope,
    required int paragraphIndex,
    required int tokenIndex,
    required String paragraph,
  }) {
    setState(() {
      _readingSelection = selectionFromSentence(
        scope: scope,
        paragraphIndex: paragraphIndex,
        tokenIndex: tokenIndex,
        tokens: tokenizeReadingParagraph(paragraph),
      );
    });
  }

  Future<void> _openCapture([String? term]) async {
    final initial = (term ?? _selectedText)?.trim();
    if (initial == null || initial.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SaveVocabFromTextSheet(
        text: _text,
        initialTerm: initial,
      ),
    );
    if (mounted) _clearReadingSelection();
  }

  String _lineKey(InlineTranslationUnit unit) {
    return '${_text.id}:${translationLocaleFromAppLanguage(_translationTargetLang)}:${unit.id}';
  }

  Future<void> _toggleInlineTranslation() async {
    if (_showInlineTranslation) {
      setState(() {
        _showInlineTranslation = false;
        _translationError = null;
        _readingSelection = null;
      });
      return;
    }
    setState(() {
      _showInlineTranslation = true;
      _readingSelection = null;
    });
    await _loadInlineTranslations();
  }

  Future<void> _loadInlineTranslations() async {
    final units = buildInlineTranslationUnits(_text.content);
    final locale = translationLocaleFromAppLanguage(_translationTargetLang);
    final missing = units
        .where((unit) => !_translations.containsKey(_lineKey(unit)))
        .toList();
    if (missing.isEmpty) {
      setState(() => _translationError = null);
      return;
    }

    final requestId = ++_translationRequestId;
    setState(() {
      _translatingInline = true;
      _translationError = null;
      for (final unit in missing) {
        _loadingKeys.add(_lineKey(unit));
      }
    });

    final repo = ref.read(libraryRepositoryProvider);
    try {
      final cache = await repo.fetchTranslationCache(
        text: _text,
        targetLocale: locale,
        segmentKeys: [for (final unit in missing) unit.id],
      );
      if (!mounted || requestId != _translationRequestId) return;

      final unresolved = <InlineTranslationUnit>[];
      for (final unit in missing) {
        final hash = hashTranslationSource(unit.text);
        final cached = extractPrimaryTranslation(
          cache['${unit.id}:$hash'] ?? '',
        );
        final key = _lineKey(unit);
        if (cached.isNotEmpty) {
          _translations[key] = cached;
          _loadingKeys.remove(key);
        } else {
          unresolved.add(unit);
        }
      }
      setState(() {});

      var failedCount = 0;
      for (final unit in unresolved) {
        if (!mounted || requestId != _translationRequestId) return;
        final key = _lineKey(unit);
        final translated = await repo.translateSentence(
          text: unit.text,
          language: _text.language,
          targetLocale: locale,
        );
        if (!mounted || requestId != _translationRequestId) return;
        if (translated == null || translated.isEmpty) {
          failedCount += 1;
          _loadingKeys.remove(key);
          setState(() {});
          continue;
        }
        _translations[key] = translated;
        _loadingKeys.remove(key);
        setState(() {});
        try {
          await repo.upsertTranslationCache(
            text: _text,
            targetLocale: locale,
            segmentKey: unit.id,
            sourceText: unit.text,
            sourceHash: hashTranslationSource(unit.text),
            translation: translated,
          );
        } catch (_) {}
      }

      if (!mounted || requestId != _translationRequestId) return;
      setState(() {
        _translatingInline = false;
        if (failedCount == 1) {
          _translationError = 'Não foi possível traduzir 1 trecho.';
        } else if (failedCount > 1) {
          _translationError = 'Não foi possível traduzir $failedCount trechos.';
        }
      });
    } catch (_) {
      if (!mounted || requestId != _translationRequestId) return;
      setState(() {
        _translatingInline = false;
        _translationError = 'Não foi possível traduzir o texto agora.';
      });
    }
  }

  Widget _tappableParagraph({
    required String scope,
    required int paragraphIndex,
    required String paragraph,
  }) {
    final selected = _readingSelection;
    final isActive =
        selected != null &&
        selected.scope == scope &&
        selected.paragraphIndex == paragraphIndex;
    return TappableReadingParagraph(
      text: paragraph,
      style: _readingTextStyle,
      selectedStart: isActive ? selected.startToken : null,
      selectedEnd: isActive ? selected.endToken : null,
      onTapToken: (tokenIndex) => _onTapReadingToken(
        scope: scope,
        paragraphIndex: paragraphIndex,
        tokenIndex: tokenIndex,
        paragraph: paragraph,
      ),
      onLongPressToken: (tokenIndex) => _onLongPressReadingToken(
        scope: scope,
        paragraphIndex: paragraphIndex,
        tokenIndex: tokenIndex,
        paragraph: paragraph,
      ),
    );
  }

  List<Widget> _inlineTranslationBody(BuildContext context) {
    final units = buildInlineTranslationUnits(_text.content);
    return [
      for (var i = 0; i < units.length; i++) ...[
        Padding(
          padding: EdgeInsets.only(
            top: i == 0 ? 0 : (units[i].startsNewParagraph ? 16 : 10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tappableParagraph(
                scope: 'inline',
                paragraphIndex: i,
                paragraph: units[i].text,
              ),
              const SizedBox(height: 4),
              Text(
                _loadingKeys.contains(_lineKey(units[i]))
                    ? 'Traduzindo…'
                    : (_translations[_lineKey(units[i])] ??
                          'Tradução indisponível'),
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: AppColors.foreground,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _readingBody() {
    final paragraphs = readingParagraphs(_text.content);
    return [
      for (var i = 0; i < paragraphs.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.lg),
        _tappableParagraph(
          scope: 'body',
          paragraphIndex: i,
          paragraph: paragraphs[i],
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isRead =
        ref.watch(libraryControllerProvider).value?.isRead(_text.id) ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundMuted,
      extendBody: false,
      floatingActionButton: _selectedText == null ? const NotebookFab() : null,
      bottomNavigationBar: _selectedText == null
          ? null
          : Material(
              color: AppColors.background,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Limpar seleção',
                        onPressed: _clearReadingSelection,
                        icon: const Icon(LucideIcons.x),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openCapture(),
                          icon: const Icon(LucideIcons.book_plus, size: 18),
                          label: Text(
                            'Salvar "${_truncatedSelection(_selectedText!)}"',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReadingCircleButton(
                    icon: LucideIcons.arrow_left,
                    tooltip: 'Voltar',
                    onPressed: _closeReading,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _text.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (!_text.isOwned)
                    _ReadingCircleButton(
                      icon: LucideIcons.check,
                      tooltip: isRead
                          ? 'Marcar como não lido'
                          : 'Marcar como lido',
                      filled: isRead,
                      onPressed: () => ref
                          .read(libraryControllerProvider.notifier)
                          .toggleRead(_text),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _ReadingChip(
                          label:
                              taughtLanguages[_text.language] ?? _text.language,
                        ),
                        if (_text.cefr != null)
                          _ReadingChip(label: _text.cefr!),
                        if (_text.sourceKind == LibraryTextSource.temporary &&
                            _text.expiresAt != null)
                          _ReadingChip(
                            label: 'Expira em ${_text.formatExpiresIn()}',
                          ),
                      ],
                    ),
                    if (_text.sourceKind == LibraryTextSource.temporary) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: _savingPersonal ? null : _saveToPersonal,
                        child: Text(
                          _savingPersonal
                              ? 'Guardando…'
                              : 'Guardar nos pessoais',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _AudioPlayerCard(
                      player: _player,
                      loading: _loadingAudio,
                      playing: _isPlaying,
                      rate: _playbackRate,
                      voiceGender: _voiceGender,
                      error: _audioError,
                      onToggle: _toggleAudio,
                      onNudgeRate: _nudgeRate,
                      onChangeVoice: _changeVoice,
                    ),
                    if (_ownedError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _ownedError!,
                        style: const TextStyle(color: AppColors.destructive),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _TranslationBar(
                      enabled: _showInlineTranslation,
                      loading: _translatingInline,
                      targetLanguage: _translationTargetLang,
                      sourceLanguage: _text.language,
                      onToggle: _toggleInlineTranslation,
                      onLanguageSelected: (value) {
                        if (value == _translationTargetLang) return;
                        setState(() {
                          _translationTargetLang = value;
                          _translations.clear();
                        });
                        if (_showInlineTranslation) {
                          unawaited(_loadInlineTranslations());
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Toque numa palavra. Toque em outra para a frase. Toque de novo para desmarcar.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_showInlineTranslation)
                      ..._inlineTranslationBody(context)
                    else
                      ..._readingBody(),
                    if (_showInlineTranslation && _translationError != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _translationError!,
                        style: const TextStyle(color: AppColors.destructive),
                      ),
                    ],
                    if (_questionSet != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _openQuestions,
                          child: const Text('Perguntas de compreensão'),
                        ),
                      ),
                    ] else if (_text.isOwned && !_loadingQuestions) ...[
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _generatingQuestions
                              ? null
                              : _generateQuestions,
                          child: Text(
                            _generatingQuestions
                                ? 'Gerando…'
                                : 'Gerar perguntas com IA',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _readingCardRadius = BorderRadius.all(Radius.circular(16));

final _readingTextStyle = TextStyle(
  fontFamily: AppTypography.titleFontFamily,
  fontSize: 18,
  height: 1.55,
  fontWeight: FontWeight.w400,
  color: AppColors.heading,
);

String _truncatedSelection(String text) {
  final compact = text.replaceAll(RegExp(r'\s+'), ' ');
  if (compact.length <= 28) return compact;
  return '${compact.substring(0, 28).trimRight()}…';
}

String _formatAudioDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _ReadingCircleButton extends StatelessWidget {
  const _ReadingCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? AppColors.primary : AppColors.background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: filled ? null : Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              size: 20,
              color: filled ? Colors.white : AppColors.heading,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadingChip extends StatelessWidget {
  const _ReadingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AudioPlayerCard extends StatelessWidget {
  const _AudioPlayerCard({
    required this.player,
    required this.loading,
    required this.playing,
    required this.rate,
    required this.voiceGender,
    required this.onToggle,
    required this.onNudgeRate,
    required this.onChangeVoice,
    this.error,
  });

  final AudioPlayer player;
  final bool loading;
  final bool playing;
  final double rate;
  final String voiceGender;
  final VoidCallback onToggle;
  final ValueChanged<double> onNudgeRate;
  final ValueChanged<String> onChangeVoice;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      borderRadius: _readingCardRadius,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: loading ? null : onToggle,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            playing ? LucideIcons.pause : LucideIcons.play,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = player.duration ?? Duration.zero;
                    final maxMs = duration.inMilliseconds
                        .toDouble()
                        .clamp(1, double.infinity)
                        .toDouble();
                    final value = position.inMilliseconds
                        .toDouble()
                        .clamp(0, maxMs)
                        .toDouble();
                    return Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.border,
                              thumbColor: AppColors.primary,
                            ),
                            child: Slider(
                              value: value,
                              max: maxMs,
                              onChanged: duration == Duration.zero
                                  ? null
                                  : (next) => player.seek(
                                      Duration(milliseconds: next.round()),
                                    ),
                            ),
                          ),
                        ),
                        Text(
                          _formatAudioDuration(
                            duration == Duration.zero ? position : duration,
                          ),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Mais devagar',
                onPressed: () => onNudgeRate(-0.25),
                icon: const Icon(LucideIcons.minus, size: 18),
              ),
              Text(
                '${rate.toStringAsFixed(2)}x',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.heading,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Mais rápido',
                onPressed: () => onNudgeRate(0.25),
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Voz',
                onSelected: onChangeVoice,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'female', child: Text('Voz ♀')),
                  PopupMenuItem(value: 'male', child: Text('Voz ♂')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundMuted,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    voiceGender == 'female' ? 'Voz ♀' : 'Voz ♂',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.heading,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.destructive),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TranslationBar extends StatelessWidget {
  const _TranslationBar({
    required this.enabled,
    required this.loading,
    required this.targetLanguage,
    required this.sourceLanguage,
    required this.onToggle,
    required this.onLanguageSelected,
  });

  final bool enabled;
  final bool loading;
  final String targetLanguage;
  final String sourceLanguage;
  final VoidCallback onToggle;
  final ValueChanged<String> onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.languages,
              size: 18,
              color: enabled ? AppColors.primary : AppColors.foreground,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: InkWell(
                onTap: loading ? null : onToggle,
                child: Text(
                  loading ? 'Traduzindo…' : 'Tradução ao lado do texto',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: enabled ? AppColors.heading : AppColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Idioma da tradução',
              onSelected: onLanguageSelected,
              itemBuilder: (context) => [
                for (final entry in taughtLanguages.entries)
                  if (entry.key != sourceLanguage)
                    PopupMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    taughtLanguages[targetLanguage] ?? targetLanguage,
                    style: Theme.of(context).textTheme.bodySmall,
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
        const Divider(height: 1),
      ],
    );
  }
}

class _SaveVocabFromTextSheet extends ConsumerStatefulWidget {
  const _SaveVocabFromTextSheet({required this.text, this.initialTerm});

  final LibraryText text;
  final String? initialTerm;

  @override
  ConsumerState<_SaveVocabFromTextSheet> createState() =>
      _SaveVocabFromTextSheetState();
}

class _SaveVocabFromTextSheetState
    extends ConsumerState<_SaveVocabFromTextSheet> {
  late final _termController = TextEditingController(
    text: widget.initialTerm?.trim() ?? '',
  );
  final _translationController = TextEditingController();
  final _contextController = TextEditingController();
  final _descriptionController = TextEditingController();
  late VocabEntryKind _entryKind = VocabEntryKind.infer(
    widget.initialTerm ?? '',
  );
  String? _partOfSpeech;
  String? _categoryId;
  bool _enriching = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_termController.text.trim().isNotEmpty) {
      unawaited(_enrich());
    }
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
    if (term.isEmpty) {
      setState(() => _error = 'Selecione ou digite o trecho primeiro.');
      return;
    }
    setState(() {
      _enriching = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(vocabularyRepositoryProvider)
          .enrichTerm(
            term: term,
            language: widget.text.language,
            entryKind: _entryKind,
            surroundingText: widget.text.content,
          );
      if (result == null) {
        setState(
          () => _error = 'Não foi possível preencher com IA. Tente novamente.',
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
        () => _error = 'Não foi possível preencher com IA. Tente novamente.',
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
            language: widget.text.language,
            source: widget.text.sourceKind.raw,
            context: contextText,
            description: description,
            entryKind: _entryKind,
            example: contextText,
            partOfSpeech: _partOfSpeech,
            captureSurface: term,
            libraryTextId: widget.text.sourceKind == LibraryTextSource.library
                ? widget.text.id
                : null,
            temporaryTextId:
                widget.text.sourceKind == LibraryTextSource.temporary
                ? widget.text.id
                : null,
            personalTextId: widget.text.sourceKind == LibraryTextSource.personal
                ? widget.text.id
                : null,
            categoryIds: _categoryId == null ? const [] : [_categoryId!],
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
    final categories =
        ref.watch(vocabularyCategoriesProvider).value ??
        const <VocabCategory>[];

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
            const SizedBox(height: 8),
            Text(
              'A palavra ou frase já vem do trecho que você selecionou.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<VocabEntryKind>(
              segments: const [
                ButtonSegment(
                  value: VocabEntryKind.word,
                  label: Text('Palavra'),
                ),
                ButtonSegment(
                  value: VocabEntryKind.sentence,
                  label: Text('Frase'),
                ),
              ],
              selected: {_entryKind},
              onSelectionChanged: (value) =>
                  setState(() => _entryKind = value.first),
            ),
            const SizedBox(height: 12),
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
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria (opcional)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nenhuma')),
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ],
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
