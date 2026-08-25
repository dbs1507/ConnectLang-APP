/// Espelha `StudyCoachPlan`/`StudyCoachAction`/`StudyCoachEvidenceItem` de
/// `src/lib/studyCoach.ts` — só os campos usados pra renderizar o plano.
/// Fica fora desta fatia: localização do conteúdo por idioma da UI
/// (`studyCoachCopy.ts` — o app mobile só gera em português), histórico de
/// planos anteriores, `softStruggle`/`coachMode`/`catalogFallback`.
enum StudyCoachActionType {
  vocabularyReview,
  dictationPractice,
  readText,
  reviewMistakes,
  addWords,
  notebookReview,
  aiNotesReview,
  productionTask,
  unknown,
}

StudyCoachActionType _actionTypeFromRaw(String? raw) {
  switch (raw) {
    case 'vocabulary_review':
      return StudyCoachActionType.vocabularyReview;
    case 'dictation_practice':
      return StudyCoachActionType.dictationPractice;
    case 'read_text':
      return StudyCoachActionType.readText;
    case 'review_mistakes':
      return StudyCoachActionType.reviewMistakes;
    case 'add_words':
      return StudyCoachActionType.addWords;
    case 'notebook_review':
      return StudyCoachActionType.notebookReview;
    case 'ai_notes_review':
      return StudyCoachActionType.aiNotesReview;
    case 'production_task':
      return StudyCoachActionType.productionTask;
    default:
      return StudyCoachActionType.unknown;
  }
}

class StudyCoachAction {
  const StudyCoachAction({
    required this.type,
    required this.title,
    required this.reason,
    required this.route,
    required this.priority,
  });

  final StudyCoachActionType type;
  final String title;
  final String reason;
  final String route;
  final int priority;

  factory StudyCoachAction.fromRow(Map<String, dynamic> row) {
    return StudyCoachAction(
      type: _actionTypeFromRaw(row['type'] as String?),
      title: (row['title'] as String? ?? '').trim(),
      reason: (row['reason'] as String? ?? '').trim(),
      route: (row['route'] as String? ?? '').trim(),
      priority: (row['priority'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudyCoachEvidenceItem {
  const StudyCoachEvidenceItem({required this.text, this.route, this.linkLabel});

  final String text;
  final String? route;
  final String? linkLabel;

  factory StudyCoachEvidenceItem.fromRow(Map<String, dynamic> row) {
    return StudyCoachEvidenceItem(
      text: (row['text'] as String? ?? '').trim(),
      route: (row['route'] as String?)?.trim(),
      linkLabel: (row['linkLabel'] as String?)?.trim(),
    );
  }
}

class StudyCoachPlan {
  const StudyCoachPlan({
    required this.summary,
    required this.focusAreas,
    required this.nextActions,
    required this.evidence,
    required this.generatedAt,
    required this.source,
    required this.cached,
  });

  final String summary;
  final List<String> focusAreas;
  final List<StudyCoachAction> nextActions;
  final List<StudyCoachEvidenceItem> evidence;
  final DateTime? generatedAt;
  final String source; // 'ai' | 'fallback'
  final bool cached;

  static StudyCoachPlan? fromRow(Map<String, dynamic> row) {
    final summary = (row['summary'] as String? ?? '').trim();
    final rawActions = row['nextActions'];
    final nextActions = rawActions is List
        ? rawActions
            .whereType<Map>()
            .map((a) => StudyCoachAction.fromRow(Map<String, dynamic>.from(a)))
            .where((a) => a.title.isNotEmpty && a.route.isNotEmpty)
            .toList()
        : <StudyCoachAction>[];
    if (summary.isEmpty || nextActions.isEmpty) return null;

    final rawEvidence = row['evidence'];
    final evidence = rawEvidence is List
        ? rawEvidence
            .whereType<Map>()
            .map((e) => StudyCoachEvidenceItem.fromRow(Map<String, dynamic>.from(e)))
            .where((e) => e.text.isNotEmpty)
            .take(5)
            .toList()
        : <StudyCoachEvidenceItem>[];

    final rawFocus = row['focusAreas'];
    final focusAreas = rawFocus is List ? rawFocus.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : <String>[];

    return StudyCoachPlan(
      summary: summary,
      focusAreas: focusAreas,
      nextActions: nextActions,
      evidence: evidence,
      generatedAt: DateTime.tryParse(row['generatedAt'] as String? ?? ''),
      source: row['source'] == 'ai' ? 'ai' : 'fallback',
      cached: row['cached'] == true,
    );
  }
}
