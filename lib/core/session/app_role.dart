/// Espelha `AppRole` de `src/contexts/AuthContext.tsx` do web.
///
/// O app mobile só dá suporte de fato a [student] e [subscriber] (ver
/// docs/planejamento.md, seção "Escopo"). [teacher]/[admin] são reconhecidos
/// aqui só para detectar login de conta incompatível e mostrar uma tela
/// explicando que esse perfil usa o site.
enum AppRole {
  admin,
  teacher,
  student,
  subscriber;

  static AppRole fromRaw(String? raw) {
    return AppRole.values.firstWhere(
      (role) => role.name == raw,
      orElse: () => AppRole.student,
    );
  }

  bool get isSupportedInApp => this == student || this == subscriber;
}
