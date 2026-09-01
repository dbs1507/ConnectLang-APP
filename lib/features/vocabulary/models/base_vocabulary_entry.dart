/// Recorte de `BaseVocabularyRow` (`src/lib/fetchAllBaseVocabulary.ts`).
class BaseVocabularyEntry {
  const BaseVocabularyEntry({
    required this.id,
    required this.term,
    required this.translation,
    required this.language,
    required this.cefr,
    this.example,
    this.description,
    this.categoryIds = const [],
  });

  final String id;
  final String term;
  final String translation;
  final String language;
  final String cefr;
  final String? example;
  final String? description;
  final List<String> categoryIds;

  factory BaseVocabularyEntry.fromRow(
    Map<String, dynamic> row, {
    List<String> categoryIds = const [],
  }) {
    return BaseVocabularyEntry(
      id: row['id'] as String,
      term: row['term'] as String? ?? '',
      translation: row['translation'] as String? ?? '',
      language: (row['language'] as String? ?? '').toUpperCase(),
      cefr: (row['cefr'] as String? ?? '').toUpperCase(),
      example: row['example'] as String?,
      description: row['description'] as String?,
      categoryIds: categoryIds,
    );
  }
}
