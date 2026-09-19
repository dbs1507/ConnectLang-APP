import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/app_role.dart';
import '../features/study_coach/lia_preparing_page.dart';
import '../features/study_coach/models/study_coach_plan.dart';
import 'learner_routes.dart';

/// Abre uma rota gerada pela LIA. Primeiro entra numa tela de espera
/// ("Carregando ditado gerado pela IA…") e só então o conteúdo pronto.
Future<void> openLearnerRoute(
  BuildContext context,
  WidgetRef ref, {
  required String route,
  required AppRole role,
  StudyCoachPlan? seedCoachPlan,
}) async {
  var target = adaptLearnerRoute(route, role);
  if (!target.startsWith('/')) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Essa ação ainda não está disponível no app.'),
      ),
    );
    return;
  }

  final uri = Uri.parse('https://app$target');
  final path = uri.path;
  final kind = _kindForPath(path);

  if (kind == LiaLaunchKind.reading) {
    final textId =
        uri.queryParameters['text_id'] ?? uri.queryParameters['textId'];
    if (textId == null || textId.isEmpty) {
      context.go(LearnerPaths.library(role));
      return;
    }
  }

  if (kind == LiaLaunchKind.other) {
    if (path.endsWith('/perfil')) {
      context.go(LearnerPaths.profile());
      return;
    }
    context.go(target);
    return;
  }

  final shell = StatefulNavigationShell.maybeOf(context);
  final shellNavigator = kind == LiaLaunchKind.coach
      ? Navigator.of(context, rootNavigator: false)
      : null;

  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => LiaPreparingPage(
        kind: kind,
        route: target,
        seedPlan: kind == LiaLaunchKind.coach ? seedCoachPlan : null,
        onRevealTab: () {
          final index = switch (kind) {
            LiaLaunchKind.vocabulary => 1,
            LiaLaunchKind.reading => 2,
            LiaLaunchKind.dictation => 3,
            _ => null,
          };
          if (index != null) shell?.goBranch(index);
        },
        onReadyInShell: shellNavigator == null
            ? null
            : (page) {
                if (!shellNavigator.mounted) return;
                shellNavigator.push(
                  MaterialPageRoute<void>(builder: (_) => page),
                );
              },
      ),
    ),
  );
}

LiaLaunchKind _kindForPath(String path) {
  if (path.endsWith('/ditado')) return LiaLaunchKind.dictation;
  if (path.endsWith('/biblioteca')) return LiaLaunchKind.reading;
  if (path.endsWith('/vocabulario')) return LiaLaunchKind.vocabulary;
  if (path.contains('/producao-demanda/')) return LiaLaunchKind.production;
  if (path.contains('/caderno')) return LiaLaunchKind.notebook;
  if (path.contains('/assistente')) return LiaLaunchKind.coach;
  return LiaLaunchKind.other;
}
