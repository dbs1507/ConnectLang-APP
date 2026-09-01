import 'placement_item.dart';

/// Espelha `PlacementDimensionScore` de `src/lib/placementTest.ts`.
class PlacementDimensionScore {
  const PlacementDimensionScore({
    required this.correct,
    required this.total,
    required this.ratio,
  });

  final int correct;
  final int total;
  final double ratio;

  factory PlacementDimensionScore.fromRow(Map<String, dynamic> row) {
    return PlacementDimensionScore(
      correct: (row['correct'] as num?)?.toInt() ?? 0,
      total: (row['total'] as num?)?.toInt() ?? 0,
      ratio: (row['ratio'] as num?)?.toDouble() ?? 0,
    );
  }
}

Map<String, PlacementDimensionScore> _dimensionScoresFromRow(dynamic raw) {
  if (raw is! Map) return const {};
  return raw.map(
    (key, value) => MapEntry(
      key.toString(),
      PlacementDimensionScore.fromRow(Map<String, dynamic>.from(value as Map)),
    ),
  );
}

/// Resultado de `placement_start_test`/`placement_submit_answer`/
/// `placement_submit_production` — o Postgres já devolve os dois formatos
/// (`in_progress` com próximo item, ou `completed` com o resultado final) no
/// mesmo shape de JSON; aqui é um único model em vez da união de tipos do
/// TS (`PlacementSubmitContinue` | `PlacementSubmitDone`).
class PlacementStepResult {
  const PlacementStepResult({
    required this.sessionId,
    required this.completed,
    required this.language,
    required this.itemsServed,
    this.correct,
    this.correctOption,
    this.currentCefr,
    this.resultCefr,
    this.dimensionScores = const {},
    this.item,
  });

  final String sessionId;
  final bool completed;
  final String language;
  final int itemsServed;
  final bool? correct;
  final String? correctOption;
  final String? currentCefr;
  final String? resultCefr;
  final Map<String, PlacementDimensionScore> dimensionScores;
  final PlacementItem? item;

  factory PlacementStepResult.fromRow(
    Map<String, dynamic> row, {
    required String fallbackLanguage,
  }) {
    final status = (row['status'] as String? ?? '').toLowerCase();
    final rawItem = row['item'];
    return PlacementStepResult(
      sessionId: row['sessionId'] as String? ?? '',
      completed: status == 'completed',
      language: (row['language'] as String? ?? fallbackLanguage).toUpperCase(),
      itemsServed: (row['itemsServed'] as num?)?.toInt() ?? 0,
      correct: row['correct'] as bool?,
      correctOption: row['correctOption'] as String?,
      currentCefr: row['currentCefr'] as String?,
      resultCefr: row['resultCefr'] as String?,
      dimensionScores: _dimensionScoresFromRow(row['dimensionScores']),
      item: rawItem is Map
          ? PlacementItem.fromRow(Map<String, dynamic>.from(rawItem))
          : null,
    );
  }
}
