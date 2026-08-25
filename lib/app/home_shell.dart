import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/auth_controller.dart';
import '../features/dictation/dictation_home_page.dart';
import '../features/library/library_list_page.dart';
import '../features/notebook/notebook_list_page.dart';
import '../features/placement/placement_home_page.dart';
import '../features/study_coach/study_coach_home_page.dart';
import '../features/vocabulary/vocabulary_list_page.dart';

/// Placeholder de navegação por role — vira o shell real (bottom nav /
/// drawer com as features) conforme os itens 2+ do roadmap forem entrando.
class _LearnerHomeScaffold extends ConsumerWidget {
  const _LearnerHomeScaffold({required this.title, this.showStudyCoach = false});

  final String title;
  final bool showStudyCoach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return Scaffold(
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VocabularyListPage()),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text('Caderno'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotebookListPage()),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Biblioteca'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LibraryListPage()),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.headphones),
              label: const Text('Ditado'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DictationHomePage()),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.school_outlined),
              label: const Text('Nivelamento'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlacementHomePage()),
              ),
            ),
            if (showStudyCoach) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Study Coach'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StudyCoachHomePage()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StudentHomePage extends StatelessWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context) => const _LearnerHomeScaffold(title: 'ConnectLang');
}

class SubscriberHomePage extends StatelessWidget {
  const SubscriberHomePage({super.key});

  @override
  Widget build(BuildContext context) => const _LearnerHomeScaffold(title: 'ConnectLang', showStudyCoach: true);
}
