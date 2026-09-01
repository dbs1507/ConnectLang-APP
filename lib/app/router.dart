import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/app_role.dart';
import '../core/session/auth_controller.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/reset_password_page.dart';
import '../features/auth/subscription_inactive_page.dart';
import '../features/auth/unsupported_role_page.dart';
import '../features/dictation/dictation_home_page.dart';
import '../features/library/library_list_page.dart';
import '../features/notebook/notebook_list_page.dart';
import '../features/placement/placement_home_page.dart';
import '../features/profile/subscriber_profile_page.dart';
import '../features/study_coach/production_demand_page.dart';
import '../features/study_coach/study_coach_home_page.dart';
import '../features/subscription/subscription_status_page.dart';
import '../features/vocabulary/vocabulary_list_page.dart';
import 'home_shell.dart';
import 'learner_routes.dart';

/// Espelha `homeForRole`/`RequireRole`/`RequireActiveSubscription` de
/// `src/App.tsx`, com as mesmas rotas `/estudo/...` e `/aluno/...` do site.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: LearnerPaths.login,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: LearnerPaths.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: LearnerPaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: LearnerPaths.resetPassword,
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: LearnerPaths.unsupported,
        builder: (context, state) => const UnsupportedRolePage(),
      ),
      GoRoute(
        path: LearnerPaths.subscription,
        builder: (context, state) => const _SubscriptionRoutePage(),
      ),
      GoRoute(
        path: LearnerPaths.studentHome,
        builder: (context, state) => const StudentHomePage(),
        routes: _learnerFeatureRoutes(),
      ),
      GoRoute(
        path: LearnerPaths.subscriberHome,
        builder: (context, state) => const SubscriberHomePage(),
        routes: [
          GoRoute(
            path: 'perfil',
            builder: (context, state) => const SubscriberProfilePage(),
          ),
          GoRoute(
            path: 'assistente',
            builder: (context, state) => StudyCoachHomePage(
              initialLanguage: state.uri.queryParameters['lang'],
            ),
          ),
          GoRoute(
            path: 'producao-demanda/:id',
            builder: (context, state) => ProductionDemandPage(
              assignmentId: state.pathParameters['id'] ?? '',
            ),
          ),
          ..._learnerFeatureRoutes(),
        ],
      ),
    ],
  );
});

List<RouteBase> _learnerFeatureRoutes() {
  return [
    GoRoute(
      path: 'vocabulario',
      builder: (context, state) => const VocabularyListPage(),
    ),
    GoRoute(
      path: 'biblioteca',
      builder: (context, state) =>
          LibraryListPage(initialTextId: state.uri.queryParameters['text_id']),
    ),
    GoRoute(
      path: 'caderno',
      builder: (context, state) => NotebookListPage(
        showAiOnly: state.uri.queryParameters['tab'] == 'ai',
      ),
    ),
    GoRoute(
      path: 'ditado',
      builder: (context, state) => DictationHomePage.fromRoute(
        locationWithQuery(state.uri),
        fallbackLanguage: state.uri.queryParameters['lang'] ?? 'EN',
      ),
    ),
    GoRoute(
      path: 'nivelamento',
      builder: (context, state) => const PlacementHomePage(),
    ),
    GoRoute(
      path: 'nivelamento/:lang',
      builder: (context, state) =>
          PlacementHomePage(initialLanguage: state.pathParameters['lang']),
    ),
  ];
}

String? _redirect(Ref ref, GoRouterState state) {
  if (state.uri.scheme == 'connectlang') {
    final host = state.uri.host;
    if (host == 'redefinir-senha' ||
        host == 'reset-password' ||
        state.uri.path == LearnerPaths.resetPassword) {
      return LearnerPaths.resetPassword;
    }
  }

  final authState = ref.read(authControllerProvider);
  if (authState.isLoading) return null;

  final user = authState.value;
  final path = state.uri.path;
  final full = locationWithQuery(state.uri);

  const publicPaths = {
    LearnerPaths.login,
    LearnerPaths.forgotPassword,
    LearnerPaths.resetPassword,
  };

  if (user == null) {
    return publicPaths.contains(path) ? null : LearnerPaths.login;
  }

  if (!user.role.isSupportedInApp) {
    return path == LearnerPaths.unsupported ? null : LearnerPaths.unsupported;
  }

  if (path == LearnerPaths.resetPassword) return null;

  if (user.role == AppRole.subscriber) {
    final allowed = user.subscription?.status?.allowsAccess ?? false;
    if (!allowed) {
      return path == LearnerPaths.subscription
          ? null
          : LearnerPaths.subscription;
    }
    if (path == LearnerPaths.login ||
        path == LearnerPaths.forgotPassword ||
        path == LearnerPaths.unsupported ||
        path == LearnerPaths.studentHome ||
        path.startsWith('${LearnerPaths.studentHome}/')) {
      if (path == LearnerPaths.studentHome ||
          path.startsWith('${LearnerPaths.studentHome}/')) {
        return adaptLearnerRoute(full, AppRole.subscriber);
      }
      return LearnerPaths.subscriberHome;
    }
    if (path == LearnerPaths.subscription ||
        path == LearnerPaths.subscriberHome ||
        path.startsWith('${LearnerPaths.subscriberHome}/')) {
      if (path == '/estudo/corrigir') {
        return LearnerPaths.notebook(AppRole.subscriber, aiOnly: true);
      }
      return null;
    }
    return LearnerPaths.subscriberHome;
  }

  if (path == LearnerPaths.login ||
      path == LearnerPaths.forgotPassword ||
      path == LearnerPaths.unsupported ||
      path == LearnerPaths.subscription) {
    return LearnerPaths.studentHome;
  }
  if (path == LearnerPaths.subscriberHome ||
      path.startsWith('${LearnerPaths.subscriberHome}/')) {
    return adaptLearnerRoute(full, AppRole.student);
  }
  if (path == LearnerPaths.studentHome ||
      path.startsWith('${LearnerPaths.studentHome}/')) {
    return null;
  }
  return LearnerPaths.studentHome;
}

class _SubscriptionRoutePage extends ConsumerWidget {
  const _SubscriptionRoutePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed =
        ref
            .watch(authControllerProvider)
            .value
            ?.subscription
            ?.status
            ?.allowsAccess ??
        false;
    return allowed
        ? const SubscriptionStatusPage()
        : const SubscriptionInactivePage();
  }
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<dynamic>>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }
}
