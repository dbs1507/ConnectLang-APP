/// Recorte de `src/pages/student/StudentTextLibraryPage.tsx` no web — só
/// leitura de `texts_library` + marcar como lido. Textos temporários/pessoais
/// do aluno, atribuição de autor, perguntas de compreensão por IA e TTS
/// ficam pra depois (ver docs/PROGRESSO.md).
class LibraryText {
  const LibraryText({
    required this.id,
    required this.title,
    required this.content,
    required this.language,
    required this.createdAt,
    this.cefr,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String content;
  final String language;
  final String? cefr;
  final List<String> tags;
  final DateTime createdAt;

  factory LibraryText.fromRow(Map<String, dynamic> row) {
    return LibraryText(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      language: row['language'] as String,
      cefr: row['cefr'] as String?,
      tags: (row['tags'] as List?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
