/// Resumo de uma sessão recente — agrupamento local das tentativas
/// em `dictation_attempts` (não há tabela de sessão no backend).
class DictationRecentSession {
  const DictationRecentSession({
    required this.endedAt,
    required this.language,
    required this.correct,
    required this.total,
  });

  final DateTime endedAt;
  final String language;
  final int correct;
  final int total;

  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(endedAt.year, endedAt.month, endedAt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return '$diff dias atrás';
  }
}
