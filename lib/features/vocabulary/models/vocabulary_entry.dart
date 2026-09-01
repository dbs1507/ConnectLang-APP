import 'srs_rating.dart';
import 'srs_schedule.dart';

/// Idiomas lecionados na plataforma — espelha `TAUGHT_LANGUAGES` de
/// `src/lib/languages.ts`.
const Map<String, String> taughtLanguages = {
  'EN': 'Inglês',
  'PT': 'Português',
  'ES': 'Espanhol',
  'FR': 'Francês',
  'IT': 'Italiano',
  'DE': 'Alemão',
  'NL': 'Holandês',
  'SV': 'Sueco',
};

enum VocabEntryKind {
  word,
  sentence;

  static VocabEntryKind fromRaw(String? raw) {
    return raw == 'sentence' || raw == 'expression' ? sentence : word;
  }

  String get raw => this == sentence ? 'sentence' : 'word';

  static VocabEntryKind infer(String term) {
    return term.trim().split(RegExp(r'\s+')).length >= 2 ? sentence : word;
  }
}

/// Recorte de `MineVocabEntry` (web): palavras do próprio aluno/assinante
/// (`source = 'student'`), incluindo as copiadas da base
/// (`saved_from_base_vocab_id`). Palavras do professor ficam fora.
class VocabularyEntry {
  const VocabularyEntry({
    required this.id,
    required this.term,
    required this.translation,
    required this.language,
    required this.createdAt,
    required this.nextReview,
    required this.intervalMinutes,
    required this.srsDifficulty,
    this.description,
    this.context,
    this.example,
    this.partOfSpeech,
    this.lastRating,
    this.categoryIds = const [],
    this.savedFromBaseVocabId,
    this.entryKind = VocabEntryKind.word,
  });

  final String id;
  final String term;
  final String translation;
  final String? description;
  final String? context;
  final String? example;
  final String? partOfSpeech;
  final String language;
  final DateTime createdAt;
  final DateTime nextReview;
  final int intervalMinutes;
  final SrsRating? lastRating;
  final int srsDifficulty;
  final List<String> categoryIds;
  final String? savedFromBaseVocabId;
  final VocabEntryKind entryKind;

  bool get isDue => !nextReview.isAfter(DateTime.now());

  factory VocabularyEntry.fromRow(
    Map<String, dynamic> row, {
    List<String> categoryIds = const [],
  }) {
    final intervalMinutes = row['interval_minutes'] as int? ?? 0;
    return VocabularyEntry(
      id: row['id'] as String,
      term: row['term'] as String,
      translation: row['translation'] as String,
      description: row['description'] as String?,
      context: row['context'] as String?,
      example: row['example'] as String?,
      partOfSpeech: row['part_of_speech'] as String?,
      language: row['language'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      nextReview:
          DateTime.tryParse(row['next_review_at'] as String? ?? '') ??
          DateTime.parse(row['created_at'] as String),
      intervalMinutes: intervalMinutes,
      lastRating: SrsRating.fromRaw(row['last_rating'] as String?),
      srsDifficulty: clampSrsDifficulty(
        row['srs_difficulty'] as int? ??
            inferSrsDifficultyFromInterval(intervalMinutes),
      ),
      categoryIds: categoryIds,
      savedFromBaseVocabId: row['saved_from_base_vocab_id'] as String?,
      entryKind: VocabEntryKind.fromRaw(row['entry_kind'] as String?),
    );
  }

  VocabularyEntry copyWithReview({
    required SrsRating rating,
    required int nextIntervalMinutes,
    required int nextDifficulty,
    required DateTime nextReviewAt,
  }) {
    return VocabularyEntry(
      id: id,
      term: term,
      translation: translation,
      description: description,
      context: context,
      example: example,
      partOfSpeech: partOfSpeech,
      language: language,
      createdAt: createdAt,
      nextReview: nextReviewAt,
      intervalMinutes: nextIntervalMinutes,
      lastRating: rating,
      srsDifficulty: nextDifficulty,
      categoryIds: categoryIds,
      savedFromBaseVocabId: savedFromBaseVocabId,
      entryKind: entryKind,
    );
  }
}
