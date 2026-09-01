import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
import 'dictation_repository.dart';

final dictationRepositoryProvider = Provider<DictationRepository>((ref) {
  final userId = ref.watch(authControllerProvider).value?.id;
  if (userId == null) {
    throw StateError(
      'dictationRepositoryProvider lido sem usuário autenticado.',
    );
  }
  return DictationRepository(userId);
});
