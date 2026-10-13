import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_radius.dart';
import '../../design_system/theme/app_spacing.dart';
import 'models/srs_rating.dart';
import 'models/srs_schedule.dart';
import 'models/vocabulary_entry.dart';
import 'vocabulary_controller.dart';
import 'vocab_tts_button.dart';

enum FlashcardStudyMode { review, write, speak, mixed }

enum _CardTask { review, write, speak }

class FlashcardPracticeConfig {
  const FlashcardPracticeConfig({
    this.kind,
    this.lastRatings = const {},
    this.mode = FlashcardStudyMode.review,
  });

  /// `null` = palavras e frases.
  final VocabEntryKind? kind;
  final Set<SrsRating> lastRatings;
  final FlashcardStudyMode mode;
}

Future<void> openFlashcardPractice(
  BuildContext context, {
  VocabEntryKind? initialKind,
}) async {
  final config = await showModalBottomSheet<FlashcardPracticeConfig>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => _FlashcardSetupSheet(initialKind: initialKind),
  );
  if (config == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FlashcardPracticePage(config: config),
    ),
  );
}

/// Sessão de flashcards — a dica é a tradução (português); o termo no
/// idioma de estudo só aparece depois de virar ou verificar.
class FlashcardPracticePage extends ConsumerStatefulWidget {
  const FlashcardPracticePage({
    super.key,
    this.config = const FlashcardPracticeConfig(),
  });

  final FlashcardPracticeConfig config;

  @override
  ConsumerState<FlashcardPracticePage> createState() =>
      _FlashcardPracticePageState();
}

class _FlashcardPracticePageState extends ConsumerState<FlashcardPracticePage> {
  late final List<VocabularyEntry> _deck;
  late final List<_CardTask> _tasks;
  int _index = 0;
  bool _showAnswer = false;
  bool? _typedOk;
  int _ratedCount = 0;
  final _answerController = TextEditingController();
  final _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String _heard = '';
  String? _speechError;

  @override
  void initState() {
    super.initState();
    _deck = _buildDeck(
      ref.read(vocabularyControllerProvider).value ?? const [],
      widget.config,
    );
    final random = math.Random();
    _tasks = [
      for (var i = 0; i < _deck.length; i++)
        switch (widget.config.mode) {
          FlashcardStudyMode.review => _CardTask.review,
          FlashcardStudyMode.write => _CardTask.write,
          FlashcardStudyMode.speak => _CardTask.speak,
          FlashcardStudyMode.mixed =>
            random.nextBool() ? _CardTask.write : _CardTask.review,
        },
    ];
  }

  @override
  void dispose() {
    _answerController.dispose();
    unawaited(_speech.stop());
    super.dispose();
  }

  Future<void> _rate(SrsRating rating) async {
    final entry = _deck[_index];
    await _stopListening();
    setState(() {
      _ratedCount++;
      _index++;
      _showAnswer = false;
      _typedOk = null;
      _heard = '';
      _speechError = null;
      _answerController.clear();
    });
    await ref
        .read(vocabularyControllerProvider.notifier)
        .rate(entry.id, rating);
  }

  void _reveal() {
    unawaited(_stopListening());
    setState(() => _showAnswer = true);
  }

  Future<void> _toggleListening(String language) async {
    if (_listening) {
      await _stopListening();
      if (mounted) setState(() {});
      return;
    }
    setState(() => _speechError = null);
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _speechError = 'Não foi possível ouvir. Tente de novo.';
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          final listening = status == 'listening';
          if (_listening != listening) setState(() => _listening = listening);
        },
      );
      if (!_speechReady) {
        if (mounted) {
          setState(
            () => _speechError =
                'O microfone não está disponível neste aparelho.',
          );
        }
        return;
      }
    }
    _heard = '';
    final localeId = await _localeIdFor(language);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _heard = result.recognizedWords.trim());
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
        localeId: localeId,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
    if (mounted) setState(() => _listening = _speech.isListening);
  }

  Future<void> _stopListening() async {
    if (_speechReady && _speech.isListening) {
      await _speech.stop();
    }
    _listening = false;
  }

  Future<String?> _localeIdFor(String language) async {
    final prefix = switch (language.toUpperCase()) {
      'PT' => 'pt',
      'ES' => 'es',
      'FR' => 'fr',
      'IT' => 'it',
      'DE' => 'de',
      'NL' => 'nl',
      'SV' => 'sv',
      _ => 'en',
    };
    final locales = await _speech.locales();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(prefix)) {
        return locale.localeId;
      }
    }
    return null;
  }

  Future<void> _checkSpoken() async {
    await _stopListening();
    final spoken = _normalizeTerm(_heard);
    if (spoken.isEmpty) {
      setState(
        () => _speechError =
            'Não ouvi o termo. Toque no microfone e fale de novo.',
      );
      return;
    }
    final expected = _normalizeTerm(_deck[_index].term);
    setState(() {
      _typedOk = spoken == expected;
      _showAnswer = true;
      _speechError = null;
    });
  }

  void _checkTyped() {
    final expected = _normalizeTerm(_deck[_index].term);
    final typed = _normalizeTerm(_answerController.text);
    setState(() {
      _typedOk = typed.isNotEmpty && typed == expected;
      _showAnswer = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_deck.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundMuted,
        appBar: AppBar(
          title: const Text('Praticar'),
          backgroundColor: AppColors.backgroundMuted,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Nenhuma palavra combina com esses filtros.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_index >= _deck.length) {
      return Scaffold(
        backgroundColor: AppColors.backgroundMuted,
        appBar: AppBar(
          title: const Text('Praticar'),
          backgroundColor: AppColors.backgroundMuted,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.circle_check,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Sessão concluída! Você revisou $_ratedCount palavra(s).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xl),
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

    final entry = _deck[_index];
    final task = _tasks[_index];
    final textTheme = Theme.of(context).textTheme;
    final translation = entry.translation.trim();

    return Scaffold(
      backgroundColor: AppColors.backgroundMuted,
      appBar: AppBar(
        title: Text('${_index + 1} / ${_deck.length}'),
        backgroundColor: AppColors.backgroundMuted,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _deck.isEmpty ? 0 : _index / _deck.length,
                color: AppColors.primary,
                backgroundColor: AppColors.border,
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (entry.lastRating != null) ...[
                            Text(
                              'Última classificação desta palavra',
                              style: textTheme.labelSmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _LastRatingChip(rating: entry.lastRating!),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                          Text(
                            taughtLanguages[entry.language] ?? entry.language,
                            style: textTheme.labelMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text('Tradução (dica)', style: textTheme.labelSmall),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            translation.isEmpty ? '—' : translation,
                            style: textTheme.headlineMedium?.copyWith(
                              color: AppColors.heading,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (!_showAnswer) ...[
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              switch (task) {
                                _CardTask.speak => 'Diga o termo.',
                                _CardTask.write =>
                                  'Digite o termo com base na tradução.',
                                _CardTask.review =>
                                  'Tente lembrar o termo — depois mostre a resposta e classifique.',
                              },
                              style: textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            if (task == _CardTask.speak) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _SpeakMicButton(
                                listening: _listening,
                                onPressed: () =>
                                    _toggleListening(entry.language),
                              ),
                              if (_speechError != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _speechError!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.destructive,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _checkSpoken,
                                      child: const Text('Verificar'),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  OutlinedButton(
                                    onPressed: _reveal,
                                    child: const Text('Não sei'),
                                  ),
                                ],
                              ),
                            ] else if (task == _CardTask.write) ...[
                              const SizedBox(height: AppSpacing.lg),
                              TextField(
                                controller: _answerController,
                                textInputAction: TextInputAction.done,
                                textCapitalization: TextCapitalization.none,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  hintText: 'Escreva o termo',
                                ),
                                onSubmitted: (_) => _checkTyped(),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              FilledButton(
                                onPressed: _checkTyped,
                                child: const Text('Verificar'),
                              ),
                            ] else ...[
                              const SizedBox(height: AppSpacing.xl),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _reveal,
                                  child: const Text('Mostrar resposta'),
                                ),
                              ),
                            ],
                          ],
                          if (_showAnswer) ...[
                            if (_typedOk != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                _typedOk!
                                    ? 'Isso. Você acertou o termo.'
                                    : 'Não foi dessa vez.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: _typedOk!
                                      ? AppColors.success
                                      : AppColors.destructive,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            const Divider(),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              entry.term,
                              style: textTheme.headlineMedium?.copyWith(
                                color: AppColors.heading,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            VocabTtsButton(
                              text: entry.term,
                              language: entry.language,
                            ),
                            if ((entry.context ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                entry.context!.trim(),
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium,
                              ),
                            ],
                            if ((entry.description ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                entry.description!.trim(),
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_showAnswer) _RatingButtons(entry: entry, onRate: _rate),
            ],
          ),
        ),
      ),
    );
  }
}

List<VocabularyEntry> _buildDeck(
  List<VocabularyEntry> all,
  FlashcardPracticeConfig config,
) {
  final filtered = [
    for (final entry in all)
      if ((config.kind == null || entry.entryKind == config.kind) &&
          (config.lastRatings.isEmpty ||
              (entry.lastRating != null &&
                  config.lastRatings.contains(entry.lastRating))))
        entry,
  ];
  final due = filtered.where((entry) => entry.isDue).toList();
  return due.isNotEmpty ? due : filtered;
}

String _normalizeTerm(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _LastRatingChip extends StatelessWidget {
  const _LastRatingChip({required this.rating});

  final SrsRating rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lia,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rating.label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.heading),
      ),
    );
  }
}

class _FlashcardSetupSheet extends StatefulWidget {
  const _FlashcardSetupSheet({this.initialKind});

  final VocabEntryKind? initialKind;

  @override
  State<_FlashcardSetupSheet> createState() => _FlashcardSetupSheetState();
}

class _FlashcardSetupSheetState extends State<_FlashcardSetupSheet> {
  late VocabEntryKind? _kind = widget.initialKind;
  final Set<SrsRating> _lastRatings = {};
  FlashcardStudyMode _mode = FlashcardStudyMode.review;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        bottomInset + AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Como quer treinar?', style: textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A dica no cartão é sempre a tradução. Contexto e descrição aparecem depois, quando existirem.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Incluir nas cartas', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          _SetupOption(
            selected: _kind == VocabEntryKind.word,
            label: 'Só palavras',
            onTap: () => setState(() => _kind = VocabEntryKind.word),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SetupOption(
            selected: _kind == VocabEntryKind.sentence,
            label: 'Só frases',
            onTap: () => setState(() => _kind = VocabEntryKind.sentence),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SetupOption(
            selected: _kind == null,
            label: 'Palavras e frases',
            onTap: () => setState(() => _kind = null),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Filtrar por última marcação', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _SetupOption(
                selected: _lastRatings.contains(SrsRating.again),
                label: 'Errei',
                compact: true,
                onTap: () => _toggleRating(SrsRating.again),
              ),
              _SetupOption(
                selected: _lastRatings.contains(SrsRating.good),
                label: 'Bom',
                compact: true,
                onTap: () => _toggleRating(SrsRating.good),
              ),
              _SetupOption(
                selected: _lastRatings.contains(SrsRating.hard),
                label: 'Difícil',
                compact: true,
                onTap: () => _toggleRating(SrsRating.hard),
              ),
              _SetupOption(
                selected: _lastRatings.contains(SrsRating.easy),
                label: 'Fácil',
                compact: true,
                onTap: () => _toggleRating(SrsRating.easy),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nenhuma opção marcada: entra todo o vocabulário.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Modo de estudo', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          _SetupOption(
            selected: _mode == FlashcardStudyMode.review,
            label: 'Só revisão — lembrar e classificar ao virar.',
            onTap: () => setState(() => _mode = FlashcardStudyMode.review),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SetupOption(
            selected: _mode == FlashcardStudyMode.write,
            label: 'Escrever — digita o termo com base na tradução.',
            onTap: () => setState(() => _mode = FlashcardStudyMode.write),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SetupOption(
            selected: _mode == FlashcardStudyMode.speak,
            label: 'Falar — diz o termo no microfone, sem digitar.',
            onTap: () => setState(() => _mode = FlashcardStudyMode.speak),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SetupOption(
            selected: _mode == FlashcardStudyMode.mixed,
            label: 'Misto — revisão ou escrever, à sorte por cartão.',
            onTap: () => setState(() => _mode = FlashcardStudyMode.mixed),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    FlashcardPracticeConfig(
                      kind: _kind,
                      lastRatings: Set<SrsRating>.from(_lastRatings),
                      mode: _mode,
                    ),
                  ),
                  child: const Text('Começar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleRating(SrsRating rating) {
    setState(() {
      if (_lastRatings.contains(rating)) {
        _lastRatings.remove(rating);
      } else {
        _lastRatings.add(rating);
      }
    });
  }
}

class _SetupOption extends StatelessWidget {
  const _SetupOption({
    required this.selected,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.buttonShape,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonShape,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: compact ? AppSpacing.md : AppSpacing.lg,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? AppColors.primary : AppColors.heading,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeakMicButton extends StatefulWidget {
  const _SpeakMicButton({required this.listening, required this.onPressed});

  final bool listening;
  final VoidCallback onPressed;

  @override
  State<_SpeakMicButton> createState() => _SpeakMicButtonState();
}

class _SpeakMicButtonState extends State<_SpeakMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.listening) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _SpeakMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.listening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.listening ? 'Parar' : 'Falar',
      child: GestureDetector(
        onTap: widget.onPressed,
        child: SizedBox(
          width: 112,
          height: 112,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = widget.listening ? _pulse.value : 0.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 96 + (16 * t),
                    height: 96 + (16 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE24B4B).withValues(alpha: 0.16),
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE24B4B).withValues(alpha: 0.28),
                    ),
                  ),
                  child!,
                ],
              );
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE24B4B),
              ),
              child: Icon(
                widget.listening ? LucideIcons.pause : LucideIcons.mic,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingButtons extends StatelessWidget {
  const _RatingButtons({required this.entry, required this.onRate});

  final VocabularyEntry entry;
  final void Function(SrsRating rating) onRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final rating in SrsRating.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                ),
                onPressed: () => onRate(rating),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rating.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      formatSrsIntervalLabel(
                        getAdaptiveSrsSchedule(
                          rating: rating,
                          currentDifficulty: entry.srsDifficulty,
                        ).nextIntervalMinutes,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
