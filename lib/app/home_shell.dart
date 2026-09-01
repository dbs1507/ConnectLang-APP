import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/app_role.dart';
import '../core/session/auth_controller.dart';
import '../features/home/subscriber_dashboard_page.dart';
import '../features/notebook/notebook_fab.dart';
import 'learner_routes.dart';

/// Home do aluno de escola — atalhos até o item 7 (atividades/aulas) existir.
class _LearnerHomeScaffold extends ConsumerWidget {
  const _LearnerHomeScaffold({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    const role = AppRole.student;
    return Scaffold(
      floatingActionButton: const NotebookFab(),
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user == null ? '' : 'Bem-vindo(a), ${user.name}!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.style_outlined),
              label: const Text('Vocabulário'),
              onPressed: () => context.push(LearnerPaths.vocabulary(role)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text('Caderno'),
              onPressed: () => context.push(LearnerPaths.notebook(role)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Biblioteca'),
              onPressed: () => context.push(LearnerPaths.library(role)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.headphones),
              label: const Text('Ditado'),
              onPressed: () => context.push(LearnerPaths.dictation(role)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.school_outlined),
              label: const Text('Nivelamento'),
              onPressed: () => context.push(LearnerPaths.placement(role)),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentHomePage extends StatelessWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _LearnerHomeScaffold(title: 'ConnectLang');
}

class SubscriberHomePage extends StatelessWidget {
  const SubscriberHomePage({super.key});

  @override
  Widget build(BuildContext context) => const SubscriberDashboardPage();
}
