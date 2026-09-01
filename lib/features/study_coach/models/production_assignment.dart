/// Espelha o recorte de `subscriber_study_assignments` (kind = 'production')
/// usado em `ProductionDemandPage.tsx`.
class ProductionAssignment {
  const ProductionAssignment({
    required this.id,
    required this.language,
    required this.status,
    required this.title,
    required this.reason,
    required this.prompt,
    required this.criteria,
    required this.targetCefr,
  });

  final String id;
  final String language;
  final String status;
  final String title;
  final String reason;
  final String prompt;
  final String criteria;
  final String targetCefr;

  bool get isDone => status == 'done';

  static ProductionAssignment? fromRow(Map<String, dynamic> row) {
    if (row['kind'] != 'production') return null;
    final language = (row['language'] as String? ?? '').toUpperCase();
    if (language.isEmpty) return null;
    final rawPayload = row['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return ProductionAssignment(
      id: row['id'] as String,
      language: language,
      status: row['status'] as String? ?? '',
      title: (payload['title'] as String? ?? '').trim(),
      reason: (payload['reason'] as String? ?? '').trim(),
      prompt: (payload['prompt'] as String? ?? '').trim(),
      criteria: (payload['criteria'] as String? ?? '').trim(),
      targetCefr:
          (payload['targetCefr'] as String? ??
                  payload['target_cefr'] as String? ??
                  '')
              .trim(),
    );
  }
}

/// Espelha `CorrectSentenceResult` de `src/lib/correctSentence.ts`.
class CorrectSentenceIssue {
  const CorrectSentenceIssue({
    required this.span,
    required this.fix,
    required this.note,
  });

  final String span;
  final String fix;
  final String note;

  factory CorrectSentenceIssue.fromRow(Map<String, dynamic> row) {
    return CorrectSentenceIssue(
      span: (row['span'] as String? ?? '').trim(),
      fix: (row['fix'] as String? ?? '').trim(),
      note: (row['note'] as String? ?? '').trim(),
    );
  }
}

class CorrectSentenceResult {
  const CorrectSentenceResult({
    required this.corrected,
    required this.isAlreadyGood,
    required this.issues,
    required this.explanation,
    required this.naturalAlternative,
  });

  final String corrected;
  final bool isAlreadyGood;
  final List<CorrectSentenceIssue> issues;
  final String explanation;
  final String naturalAlternative;

  static CorrectSentenceResult? fromRow(Map<String, dynamic> row) {
    final corrected = (row['corrected'] as String? ?? '').trim();
    final explanation = (row['explanation'] as String? ?? '').trim();
    if (corrected.isEmpty || explanation.isEmpty) return null;
    final rawIssues = row['issues'];
    final issues = rawIssues is List
        ? rawIssues
              .whereType<Map>()
              .map(
                (i) =>
                    CorrectSentenceIssue.fromRow(Map<String, dynamic>.from(i)),
              )
              .where((i) => i.span.isNotEmpty || i.fix.isNotEmpty)
              .take(5)
              .toList()
        : <CorrectSentenceIssue>[];
    return CorrectSentenceResult(
      corrected: corrected,
      isAlreadyGood: row['isAlreadyGood'] == true,
      issues: issues,
      explanation: explanation,
      naturalAlternative: (row['naturalAlternative'] as String? ?? '').trim(),
    );
  }
}
