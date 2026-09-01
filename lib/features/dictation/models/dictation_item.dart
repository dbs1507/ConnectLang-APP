class DictationItem {
  const DictationItem({
    required this.id,
    required this.promptText,
    required this.language,
    this.promptTranslation,
    this.cefr,
    this.topic,
    this.practiceTags = const [],
  });

  final String id;
  final String promptText;
  final String? promptTranslation;
  final String language;
  final String? cefr;
  final String? topic;
  final List<String> practiceTags;

  factory DictationItem.fromRow(Map<String, dynamic> row) {
    final rawTags = row['practice_tags'];
    return DictationItem(
      id: row['id'] as String,
      promptText: row['prompt_text'] as String? ?? '',
      promptTranslation: row['prompt_translation'] as String?,
      language: row['language'] as String,
      cefr: row['cefr'] as String?,
      topic: row['topic'] as String?,
      practiceTags: rawTags is List
          ? rawTags.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
    );
  }
}
