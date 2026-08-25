import 'app_role.dart';
import 'subscription_info.dart';

/// Espelha `AppUser` de `src/contexts/AuthContext.tsx` do web (só os campos
/// que o app mobile usa até agora: guards de rota e saudação).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.subscription,
  });

  final String id;
  final String name;
  final String email;
  final AppRole role;
  final bool isActive;
  final SubscriptionInfo? subscription;

  factory AppUser.fromProfileRow(
    Map<String, dynamic> row, {
    SubscriptionInfo? subscription,
  }) {
    return AppUser(
      id: row['id'] as String,
      name: (row['full_name'] as String?)?.trim().isNotEmpty == true
          ? row['full_name'] as String
          : (row['email'] as String? ?? ''),
      email: row['email'] as String? ?? '',
      role: AppRole.fromRaw(row['role'] as String?),
      isActive: row['is_active'] as bool? ?? true,
      subscription: subscription,
    );
  }
}
