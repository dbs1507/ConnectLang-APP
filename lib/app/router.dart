import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/app_role.dart';
import '../core/session/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/auth/subscription_inactive_page.dart';
import '../features/auth/unsupported_role_page.dart';
import 'home_shell.dart';

const _loginPath = '/login';
const _studentHomePath = '/aluno';
const _subscriberHomePath = '/estudo';
const _subscriptionInactivePath = '/assinatura';
const _unsupportedRolePath = '/acesso-nao-suportado';

/// Espelha `homeForRole`/`RequireRole`/`RequireActiveSubscription` de
/// `src/App.tsx` no web, restrito às duas roles que o app mobile atende.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: _loginPath,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: _loginPath, builder: (context, state) => const LoginPage()),
      GoRoute(path: _studentHomePath, builder: (context, state) => const StudentHomePage()),
      GoRoute(path: _subscriberHomePath, builder: (context, state) => const SubscriberHomePage()),
      GoRoute(
        path: _subscriptionInactivePath,
        builder: (context, state) => const SubscriptionInactivePage(),
      ),
      GoRoute(
        path: _unsupportedRolePath,
        builder: (context, state) => const UnsupportedRolePage(),
      ),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authControllerProvider);
  if (authState.isLoading) return null;

  final user = authState.value;
  final location = state.matchedLocation;

  if (user == null) {
    return location == _loginPath ? null : _loginPath;
  }

  if (!user.role.isSupportedInApp) {
    return location == _unsupportedRolePath ? null : _unsupportedRolePath;
  }

  final home = user.role == AppRole.subscriber ? _subscriberHomePath : _studentHomePath;

  if (user.role == AppRole.subscriber) {
    final allowed = user.subscription?.status?.allowsAccess ?? false;
    if (!allowed) {
      return location == _subscriptionInactivePath ? null : _subscriptionInactivePath;
    }
  }

  final onOwnHome = location == home;
  final onForeignArea = location == _loginPath ||
      location == _unsupportedRolePath ||
      (user.role == AppRole.subscriber && location == _studentHomePath) ||
      (user.role == AppRole.student &&
          (location == _subscriberHomePath || location == _subscriptionInactivePath));

  if (!onOwnHome && onForeignArea) return home;
  return null;
}

/// Faz o `GoRouter` reavaliar `redirect` sempre que a sessão/perfil mudar.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<dynamic>>(authControllerProvider, (_, _) => notifyListeners());
  }
}
