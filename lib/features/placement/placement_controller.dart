import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
import 'placement_repository.dart';

/// Só usa a sessão como gate de login (os RPCs resolvem o usuário via
/// `auth.uid()` no servidor) — ver [PlacementRepository].
final placementRepositoryProvider = Provider<PlacementRepository>((ref) {
  if (ref.watch(authControllerProvider).value?.id == null) {
    throw StateError('placementRepositoryProvider lido sem usuário autenticado.');
  }
  return const PlacementRepository();
});
