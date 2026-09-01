import 'dart:math' as math;

/// Porte exato dos helpers de `src/lib/placementTest.ts` usados na
/// orquestração client-side (a escada CEFR/pontuação em si é toda
/// server-side, nos RPCs `placement_submit_*`).
const List<String> placementCefrLadder = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/// Score mínimo (0–100) para o ditado manter o CEFR do item.
const int placementDictationKeepScore = 85;

/// Mapeia score local de ditado (0–100) → CEFR ativo, limitado ao CEFR do item.
String dictationScoreToCefr(int score, String itemCefr) {
  final idx = math.max(0, placementCefrLadder.indexOf(itemCefr));
  int drop;
  if (score >= placementDictationKeepScore) {
    drop = 0;
  } else if (score >= placementDictationKeepScore - 15) {
    drop = 1; // 70–84
  } else if (score >= placementDictationKeepScore - 35) {
    drop = 2; // 50–69
  } else if (score >= 35) {
    drop = 3;
  } else {
    drop = math.min(idx, 4);
  }
  final resultIdx = math.max(0, idx - drop);
  return resultIdx < placementCefrLadder.length
      ? placementCefrLadder[resultIdx]
      : 'A1';
}

/// Feedback de produção: "precisa melhorar" (UI vermelha).
bool placementProductionNeedsWork({
  bool showModel = false,
  String? productionCefr,
  String? promptCefr,
  int? dictationScore,
  String answer = '',
  String? sourcePt,
}) {
  if (dictationScore != null && dictationScore < placementDictationKeepScore) {
    return true;
  }
  if (showModel) return true;
  if (productionCefr != null && promptCefr != null) {
    final gap =
        placementCefrLadder.indexOf(promptCefr) -
        placementCefrLadder.indexOf(productionCefr);
    if (gap >= 1) return true;
  }
  final trimmedAnswer = answer.trim();
  final trimmedSource = (sourcePt ?? '').trim();
  if (trimmedAnswer.isNotEmpty && trimmedSource.isNotEmpty) {
    final words = trimmedAnswer
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (words <= 4 ||
        trimmedAnswer.length / math.max(trimmedSource.length, 1) < 0.45) {
      return true;
    }
  } else if (trimmedAnswer.isNotEmpty) {
    final words = trimmedAnswer
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (words < 6) return true;
  }
  return false;
}

/// Soft-pass da escada: typos/1 banda abaixo não derrubam o nível reportado
/// ao servidor quando o feedback não é "precisa melhorar". Nunca usado pro
/// ditado (a nota local já é exata) nem altera o feedback vermelho/verde.
String? placementSoftPassCefr({
  required String? productionCefr,
  required String itemCefr,
  required bool needsWork,
}) {
  if (productionCefr == null) return null;
  final gap =
      placementCefrLadder.indexOf(itemCefr) -
      placementCefrLadder.indexOf(productionCefr);
  if (gap == 0 || (gap == 1 && !needsWork)) return itemCefr;
  return productionCefr;
}
