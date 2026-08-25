/// Espelha `NotebookEntryRow`/`NotebookLinkType` de `src/lib/notebook.ts` no
/// web. `link_type` do banco pode ser qualquer um dos quatro tipos do web
/// (`lesson_plan`, `activity`, `library_text`, `vocabulary`), mas o app só
/// sabe *criar* vínculo com `vocabulary` até as outras features existirem
/// aqui — os outros tipos são só exibidos (rótulo), sem navegação.
enum NotebookLinkType {
  lessonPlan,
  activity,
  libraryText,
  vocabulary;

  static NotebookLinkType? fromRaw(String? raw) {
    return switch (raw) {
      'lesson_plan' => lessonPlan,
      'activity' => activity,
      'library_text' => libraryText,
      'vocabulary' => vocabulary,
      _ => null,
    };
  }

  String get raw => switch (this) {
        lessonPlan => 'lesson_plan',
        activity => 'activity',
        libraryText => 'library_text',
        vocabulary => 'vocabulary',
      };
}

enum NotebookEntryKind {
  manual,
  aiExplanation;

  static NotebookEntryKind fromRaw(String? raw) {
    return raw == 'ai_explanation' ? aiExplanation : manual;
  }
}

class NotebookEntry {
  const NotebookEntry({
    required this.id,
    required this.content,
    required this.language,
    required this.entryKind,
    required this.createdAt,
    required this.updatedAt,
    this.linkType,
    this.linkId,
    this.linkLabel,
    this.title,
  });

  final String id;
  final String content;
  final String? language;
  final NotebookEntryKind entryKind;
  final NotebookLinkType? linkType;
  final String? linkId;
  final String? linkLabel;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory NotebookEntry.fromRow(Map<String, dynamic> row) {
    return NotebookEntry(
      id: row['id'] as String,
      content: row['content'] as String? ?? '',
      language: row['language'] as String?,
      entryKind: NotebookEntryKind.fromRaw(row['entry_kind'] as String?),
      linkType: NotebookLinkType.fromRaw(row['link_type'] as String?),
      linkId: row['link_id'] as String?,
      linkLabel: row['link_label'] as String?,
      title: row['title'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
