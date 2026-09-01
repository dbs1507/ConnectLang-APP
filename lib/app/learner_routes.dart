import '../core/session/app_role.dart';

/// Espelha `src/lib/learnerRoutes.ts`.
class LearnerPaths {
  static const login = '/login';
  static const forgotPassword = '/recuperar-senha';
  static const resetPassword = '/redefinir-senha';
  static const unsupported = '/acesso-nao-suportado';
  static const subscription = '/assinatura';
  static const studentHome = '/aluno';
  static const subscriberHome = '/estudo';

  static String home(AppRole? role) =>
      role == AppRole.subscriber ? subscriberHome : studentHome;

  static String vocabulary(AppRole? role) =>
      role == AppRole.subscriber ? '/estudo/vocabulario' : '/aluno/vocabulario';

  static String library(AppRole? role, {String? textId}) {
    final base = role == AppRole.subscriber
        ? '/estudo/biblioteca'
        : '/aluno/biblioteca';
    if (textId == null || textId.isEmpty) return base;
    return '$base?text_id=${Uri.encodeComponent(textId)}';
  }

  static String notebook(AppRole? role, {bool aiOnly = false}) {
    final base = role == AppRole.subscriber
        ? '/estudo/caderno'
        : '/aluno/caderno';
    return aiOnly ? '$base?tab=ai' : base;
  }

  static String dictation(AppRole? role, {String? query}) {
    final base = role == AppRole.subscriber
        ? '/estudo/ditado'
        : '/aluno/ditado';
    if (query == null || query.isEmpty) return base;
    return '$base?$query';
  }

  static String placement(AppRole? role, {String? lang}) {
    final base = role == AppRole.subscriber
        ? '/estudo/nivelamento'
        : '/aluno/nivelamento';
    if (lang == null || lang.isEmpty) return base;
    return '$base/${Uri.encodeComponent(lang)}';
  }

  static String coach(AppRole? role, {String? lang}) {
    if (role != AppRole.subscriber) return studentHome;
    if (lang == null || lang.isEmpty) return '/estudo/assistente';
    return '/estudo/assistente?lang=${Uri.encodeComponent(lang)}';
  }

  static String production(String id) =>
      '/estudo/producao-demanda/${Uri.encodeComponent(id)}';

  static String profile() => '/estudo/perfil';
}

String adaptLearnerRoute(String route, AppRole? role) {
  final raw = route.trim();
  if (!raw.startsWith('/')) return raw;

  final wantSubscriber = role == AppRole.subscriber;
  const fromSubscriber = '/estudo';
  const fromStudent = '/aluno';
  final from = wantSubscriber ? fromStudent : fromSubscriber;
  final to = wantSubscriber ? fromSubscriber : fromStudent;

  final pathOnly = raw.split('?').first;

  if (!wantSubscriber &&
      RegExp(r'/producao-demanda(?:/|$)').hasMatch(pathOnly)) {
    return LearnerPaths.studentHome;
  }
  if (!wantSubscriber && pathOnly == '/estudo/perfil') {
    return LearnerPaths.studentHome;
  }
  if (!wantSubscriber && pathOnly == '/estudo/assistente') {
    return LearnerPaths.studentHome;
  }

  if (raw == from || raw.startsWith('$from/') || raw.startsWith('$from?')) {
    return '$to${raw.substring(from.length)}';
  }
  return raw;
}

String locationWithQuery(Uri uri) {
  if (!uri.hasQuery) return uri.path;
  return '${uri.path}?${uri.query}';
}
