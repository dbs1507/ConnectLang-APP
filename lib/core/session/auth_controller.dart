import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';
import 'app_role.dart';
import 'app_user.dart';
import 'subscription_info.dart';

/// Equivalente ao `AuthContext.tsx` do web: mantém sessão + `profiles` (e
/// `subscriptions`, quando assinante) sincronizados, e expõe `login`/`logout`.
///
/// `state.value == null` = deslogado. `state.isLoading` = sessão/perfil ainda
/// carregando (guards de rota devem esperar antes de decidir redirecionar).
final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AppUser?> {
  StreamSubscription<AuthState>? _authSub;
  bool _manualLoginInFlight = false;

  @override
  FutureOr<AppUser?> build() {
    ref.onDispose(() => _authSub?.cancel());
    _authSub = supabase.auth.onAuthStateChange.listen(_handleAuthEvent);

    final session = supabase.auth.currentSession;
    if (session == null) return null;
    return _loadProfile(session.user.id, fallbackEmail: session.user.email);
  }

  void _handleAuthEvent(AuthState data) {
    // `initialSession` já é coberto pelo build(); login manual já se
    // resolve sozinho em login() — evita disparar uma segunda leitura do
    // profile em paralelo com a mesma resposta.
    if (data.event == AuthChangeEvent.initialSession) return;
    if (data.event == AuthChangeEvent.signedIn && _manualLoginInFlight) return;

    final session = data.session;
    if (session == null) {
      state = const AsyncData(null);
      return;
    }

    final current = state.value;
    if (data.event == AuthChangeEvent.tokenRefreshed &&
        current != null &&
        current.id == session.user.id) {
      return;
    }

    // Refresh silencioso: não zera o valor atual pra AsyncLoading — outros
    // providers (ex.: vocabularyRepositoryProvider) leem `.value` e
    // quebrariam numa janela momentânea sem usuário durante um evento de
    // fundo (ex.: token refresh de outro tipo). Mesmo espírito do
    // `loadProfile` em AuthContext.tsx no web.
    unawaited(_reloadFor(session));
  }

  Future<void> _reloadFor(Session session) async {
    state = await AsyncValue.guard(
      () => _loadProfile(session.user.id, fallbackEmail: session.user.email),
    );
  }

  Future<AppUser?> _loadProfile(String userId, {String? fallbackEmail}) async {
    try {
      final row = await supabase
          .from('profiles')
          .select('id, full_name, email, role, is_active, profile_languages, cefr_levels')
          .eq('id', userId)
          .single();

      if (row['is_active'] == false) {
        await supabase.auth.signOut();
        return null;
      }

      final role = AppRole.fromRaw(row['role'] as String?);
      SubscriptionInfo? subscription;
      if (role == AppRole.subscriber) {
        final subRow = await supabase
            .from('subscriptions')
            .select('id, plan, status, trial_ends_at, next_due_date')
            .eq('user_id', userId)
            .maybeSingle();
        if (subRow != null) subscription = SubscriptionInfo.fromRow(subRow);
      }

      return AppUser.fromProfileRow(row, subscription: subscription);
    } catch (_) {
      // Sessão válida mas leitura do profile falhou (RLS/rede): mesmo
      // fallback do web — autentica com dados mínimos em vez de travar o app.
      if (fallbackEmail == null) return null;
      return AppUser(
        id: userId,
        name: fallbackEmail.split('@').first,
        email: fallbackEmail,
        role: AppRole.student,
      );
    }
  }

  Future<void> login(String email, String password) async {
    _manualLoginInFlight = true;
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final userId = response.user?.id;
      if (userId == null) {
        await supabase.auth.signOut();
        throw const AuthException('Sessão inválida após o login.');
      }

      state = const AsyncLoading<AppUser?>();
      state = await AsyncValue.guard(
        () => _loadProfile(userId, fallbackEmail: response.user?.email),
      );

      if (state.value == null) {
        throw const AuthException('Sua conta está inativa. Fale com o suporte.');
      }
    } finally {
      _manualLoginInFlight = false;
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    state = const AsyncData(null);
  }

  Future<void> refreshProfile() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      state = const AsyncData(null);
      return;
    }
    state = await AsyncValue.guard(
      () => _loadProfile(session.user.id, fallbackEmail: session.user.email),
    );
  }
}
