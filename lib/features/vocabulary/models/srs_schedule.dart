import 'dart:math' as math;

import 'srs_rating.dart';

/// Porte exato do algoritmo de `src/pages/student/VocabularyPage.tsx`
/// (`getAdaptiveSrsSchedule` e funções auxiliares) — não reinventar a
/// fórmula aqui, só espelhar. Precisa ficar idêntico ao web porque as duas
/// pontas escrevem na mesma coluna `student_vocabulary.interval_minutes`.
const srsDifficultyInitial = 1;
const srsDifficultyMin = 1;
const srsDifficultyMax = 8;
const srsMaxIntervalDays = 180;

const Map<SrsRating, int> srsRatingBaseDays = {
  SrsRating.again: 0,
  SrsRating.hard: 1,
  SrsRating.good: 2,
  SrsRating.easy: 5,
};

const Map<SrsRating, int> srsRatingDifficultyDelta = {
  SrsRating.again: -2,
  SrsRating.hard: -1,
  SrsRating.good: 1,
  SrsRating.easy: 2,
};

int clampSrsDifficulty(num? value) {
  if (value == null || value.isNaN || value.isInfinite) return srsDifficultyInitial;
  return value.round().clamp(srsDifficultyMin, srsDifficultyMax);
}

int inferSrsDifficultyFromInterval(int? intervalMinutes) {
  final days = math.max(0, (intervalMinutes ?? 0) / 1440);
  if (days >= 100) return 4;
  if (days >= 20) return 3;
  if (days >= 4) return 2;
  return srsDifficultyInitial;
}

class SrsSchedule {
  const SrsSchedule({required this.nextIntervalMinutes, required this.nextDifficulty});

  final int nextIntervalMinutes;
  final int nextDifficulty;
}

SrsSchedule getAdaptiveSrsSchedule({
  required SrsRating rating,
  int? currentDifficulty,
  int? previousIntervalMinutes,
}) {
  final difficulty = clampSrsDifficulty(
    currentDifficulty ?? inferSrsDifficultyFromInterval(previousIntervalMinutes),
  );
  final baseDays = srsRatingBaseDays[rating]!;
  final nextInterval = baseDays <= 0
      ? 0
      : (math.min(srsMaxIntervalDays, math.pow(baseDays, difficulty)) * 1440).round();
  final nextDifficulty = clampSrsDifficulty(difficulty + srsRatingDifficultyDelta[rating]!);
  return SrsSchedule(nextIntervalMinutes: nextInterval, nextDifficulty: nextDifficulty);
}

/// Rótulo do tempo até a palavra voltar (intervalo total, não o incremento).
String formatSrsIntervalLabel(int intervalMinutes) {
  if (intervalMinutes <= 0) return 'agora';
  if (intervalMinutes < 60) {
    return 'em $intervalMinutes min';
  }
  if (intervalMinutes < 1440) {
    final hours = math.max(1, (intervalMinutes / 60).round());
    return 'em $hours h';
  }
  final days = math.max(1, (intervalMinutes / 1440).round());
  if (days == 1) return 'em 1 dia';
  return 'em $days dias';
}
