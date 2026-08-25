import 'app_role.dart';
import 'subscription_info.dart';

/// Espelha `AppUser` de `src/contexts/AuthContext.tsx` do web (só os campos
/// que o app mobile usa até agora: guards de rota, saudação e o Perfil).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.subscription,
    this.studyLanguages = const [],
    this.cefrLevelByLanguage = const {},
  });

  final String id;
  final String name;
  final String email;
  final AppRole role;
  final bool isActive;
  final SubscriptionInfo? subscription;
  final List<String> studyLanguages;
  final Map<String, String> cefrLevelByLanguage;

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
      studyLanguages: _parseStudyLanguages(row['profile_languages']),
      cefrLevelByLanguage: _parseCefrLevels(row['cefr_levels']),
    );
  }
}

const _validCefrLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};

List<String> _parseStudyLanguages(dynamic raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final item in raw) {
    final code = item.toString().toUpperCase();
    if (code.isNotEmpty && !out.contains(code)) out.add(code);
  }
  return out;
}

Map<String, String> _parseCefrLevels(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  raw.forEach((key, value) {
    final level = value?.toString().toUpperCase();
    if (level != null && _validCefrLevels.contains(level)) {
      out[key.toString().toUpperCase()] = level;
    }
  });
  return out;
}
