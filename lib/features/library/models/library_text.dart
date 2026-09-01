/// Recorte de `ReadableText` / `StudentTextLibraryPage.tsx` no web: textos
/// curados (`texts_library`) e os próprios do aluno (`student_temporary_texts`
/// / `student_personal_texts`).
enum LibraryTextSource {
  library,
  temporary,
  personal;

  String get raw => name;

  bool get isOwned => this != library;
}

class LibraryText {
  const LibraryText({
    required this.id,
    required this.title,
    required this.content,
    required this.language,
    required this.createdAt,
    this.cefr,
    this.tags = const [],
    this.sourceKind = LibraryTextSource.library,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String content;
  final String language;
  final String? cefr;
  final List<String> tags;
  final DateTime createdAt;
  final LibraryTextSource sourceKind;
  final DateTime? expiresAt;

  bool get isOwned => sourceKind.isOwned;

  factory LibraryText.fromLibraryRow(Map<String, dynamic> row) {
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

  factory LibraryText.fromTemporaryRow(Map<String, dynamic> row) {
    return LibraryText(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      language: row['language'] as String,
      cefr: row['cefr'] as String?,
      tags: (row['tags'] as List?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(row['created_at'] as String),
      sourceKind: LibraryTextSource.temporary,
      expiresAt: DateTime.tryParse(row['expires_at'] as String? ?? ''),
    );
  }

  factory LibraryText.fromPersonalRow(Map<String, dynamic> row) {
    return LibraryText(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      language: row['language'] as String,
      cefr: row['cefr'] as String?,
      tags: (row['tags'] as List?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(row['created_at'] as String),
      sourceKind: LibraryTextSource.personal,
    );
  }

  String formatExpiresIn({DateTime? now}) {
    final expires = expiresAt;
    if (expires == null) return '';
    final ms = expires.difference(now ?? DateTime.now()).inMilliseconds;
    if (ms <= 0) return '0h';
    final hours = ms ~/ (60 * 60 * 1000);
    if (hours >= 24) {
      final days = hours ~/ 24;
      final remH = hours % 24;
      return remH > 0 ? '${days}d ${remH}h' : '${days}d';
    }
    final mins = (ms % (60 * 60 * 1000)) ~/ (60 * 1000);
    if (hours <= 0) return '${mins < 1 ? 1 : mins}m';
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}
