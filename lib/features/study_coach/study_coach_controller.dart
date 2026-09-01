import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
import 'study_coach_repository.dart';

/// Só usa a sessão como gate de login — o repositório lê/escreve via RLS
/// (`auth.uid()`) e a edge function autentica pelo token da sessão atual.
final studyCoachRepositoryProvider = Provider<StudyCoachRepository>((ref) {
  if (ref.watch(authControllerProvider).value?.id == null) {
    throw StateError(
      'studyCoachRepositoryProvider lido sem usuário autenticado.',
    );
  }
  return const StudyCoachRepository();
});
