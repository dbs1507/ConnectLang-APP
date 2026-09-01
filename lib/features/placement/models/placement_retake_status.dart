/// Porte reduzido de `PlacementRetakeCooldownStatus` (`src/lib/placementTest.ts`)
/// — só os campos usados pra bloquear/liberar o botão no app. Sem o fluxo de
/// pedido de retake do aluno de escola (`placementRetakeRequest.ts`,
/// `placement_retake_grants`) nem o atalho pra sugestão do Coach.
class PlacementRetakeStatus {
  const PlacementRetakeStatus({
    required this.allowed,
    required this.reason,
    required this.daysRemaining,
    required this.practiceEventsRemaining,
  });

  final bool allowed;
  final String reason;
  final int daysRemaining;
  final int practiceEventsRemaining;

  static const PlacementRetakeStatus allowedFallback = PlacementRetakeStatus(
    allowed: true,
    reason: '',
    daysRemaining: 0,
    practiceEventsRemaining: 0,
  );

  factory PlacementRetakeStatus.fromRow(Map<String, dynamic> row) {
    return PlacementRetakeStatus(
      allowed: row['allowed'] == true,
      reason: row['reason'] as String? ?? '',
      daysRemaining: (row['daysRemaining'] as num?)?.toInt() ?? 0,
      practiceEventsRemaining:
          (row['practiceEventsRemaining'] as num?)?.toInt() ?? 0,
    );
  }

  /// Mensagem curta pra explicar o bloqueio — porte simplificado de
  /// `placement.errorRetakeLocked`/`retakeLockedStudentBody`.
  String get blockedMessage {
    if (reason == 'teacher_approval_required') {
      return 'Você já fez o nivelamento neste idioma. Peça ao professor pra liberar um novo.';
    }
    final days = daysRemaining > 0 ? daysRemaining : 14;
    final practice = practiceEventsRemaining > 0 ? practiceEventsRemaining : 15;
    return 'Nivelamento em intervalo. Aguarde ~$days dia(s) ou continue praticando (faltam ~$practice).';
  }
}
