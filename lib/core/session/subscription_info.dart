/// Espelha `SubscriptionStatus`/`isSubscriptionAllowed` de
/// `src/lib/subscriptionPlans.ts` do web.
enum SubscriptionStatus {
  trialing,
  active,
  overdue,
  canceled,
  expired;

  static SubscriptionStatus? fromRaw(String? raw) {
    if (raw == null) return null;
    for (final status in SubscriptionStatus.values) {
      if (status.name == raw) return status;
    }
    return null;
  }

  bool get allowsAccess => this == trialing || this == active;
}

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.id,
    required this.status,
    this.plan,
    this.trialEndsAt,
    this.nextDueDate,
  });

  final String id;
  final SubscriptionStatus? status;
  final String? plan;
  final DateTime? trialEndsAt;
  final DateTime? nextDueDate;

  factory SubscriptionInfo.fromRow(Map<String, dynamic> row) {
    return SubscriptionInfo(
      id: row['id'] as String,
      status: SubscriptionStatus.fromRaw(row['status'] as String?),
      plan: row['plan'] as String?,
      trialEndsAt: DateTime.tryParse(row['trial_ends_at'] as String? ?? ''),
      nextDueDate: DateTime.tryParse(row['next_due_date'] as String? ?? ''),
    );
  }
}
