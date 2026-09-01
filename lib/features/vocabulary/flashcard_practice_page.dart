import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/srs_rating.dart';
import 'models/srs_schedule.dart';
import 'models/vocabulary_entry.dart';
import 'vocabulary_controller.dart';
import 'vocab_tts_button.dart';

/// Sessão de flashcards: mesma regra do web (`FlashcardMode` em
/// `VocabularyPage.tsx`) — se há palavras vencidas (`isDue`), pratica só
/// elas; senão, pratica a lista toda.
class FlashcardPracticePage extends ConsumerStatefulWidget {
  const FlashcardPracticePage({super.key, this.kindFilter});

  final VocabEntryKind? kindFilter;

  @override
  ConsumerState<FlashcardPracticePage> createState() =>
      _FlashcardPracticePageState();
}

class _FlashcardPracticePageState extends ConsumerState<FlashcardPracticePage> {
  late final List<VocabularyEntry> _deck;
  int _index = 0;
  bool _showAnswer = false;
  int _ratedCount = 0;

  @override
  void initState() {
    super.initState();
    final all = (ref.read(vocabularyControllerProvider).value ?? [])
        .where(
          (e) => widget.kindFilter == null || e.entryKind == widget.kindFilter,
        )
        .toList();
    final due = all.where((e) => e.isDue).toList();
    _deck = due.isNotEmpty ? due : all;
  }

  Future<void> _rate(SrsRating rating) async {
    final entry = _deck[_index];
    setState(() {
      _ratedCount++;
      _index++;
      _showAnswer = false;
    });
    await ref
        .read(vocabularyControllerProvider.notifier)
        .rate(entry.id, rating);
  }

  @override
  Widget build(BuildContext context) {
    if (_deck.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Praticar')),
        body: const Center(child: Text('Nenhuma palavra pra praticar ainda.')),
      );
    }

    if (_index >= _deck.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Praticar')),
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
                  'Sessão concluída! Você revisou $_ratedCount palavra(s).',
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

    final entry = _deck[_index];

    return Scaffold(
      appBar: AppBar(title: Text('${_index + 1} / ${_deck.length}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LinearProgressIndicator(value: _index / _deck.length),
              const SizedBox(height: 24),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showAnswer = true),
                  child: Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                taughtLanguages[entry.language] ??
                                    entry.language,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                entry.term,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                                textAlign: TextAlign.center,
                              ),
                              VocabTtsButton(
                                text: entry.term,
                                language: entry.language,
                              ),
                              if (!_showAnswer) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'Toque pra ver a resposta',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                              if (_showAnswer) ...[
                                const Divider(height: 40),
                                Text(
                                  entry.translation,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                                if ((entry.context ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    entry.context!.trim(),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_showAnswer) _RatingButtons(entry: entry, onRate: _rate),
            ],
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
