import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/learner_routes.dart';
import '../../core/session/app_role.dart';
import '../../core/session/auth_controller.dart';
import '../notebook/notebook_fab.dart';
import '../study_coach/models/study_coach_plan.dart';
import '../study_coach/study_assignments_repository.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'subscriber_dashboard_repository.dart';

final subscriberDashboardRepositoryProvider =
    Provider<SubscriberDashboardRepository>((ref) {
      final userId = ref.watch(authControllerProvider).value?.id;
      if (userId == null) {
        throw StateError(
          'subscriberDashboardRepositoryProvider lido sem usuário autenticado.',
        );
      }
      return SubscriberDashboardRepository(userId);
    });

class SubscriberDashboardPage extends ConsumerStatefulWidget {
  const SubscriberDashboardPage({super.key});

  @override
  ConsumerState<SubscriberDashboardPage> createState() =>
      _SubscriberDashboardPageState();
}

class _SubscriberDashboardPageState
    extends ConsumerState<SubscriberDashboardPage> {
  String? _studyLanguage;
  bool _loading = true;
  String? _error;
  SubscriberDashboardData? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final user = ref.read(authControllerProvider).value;
    final languages = user?.studyLanguages ?? const <String>[];
    _studyLanguage = languages.isEmpty ? null : languages.first;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      unawaited(const StudyAssignmentsRepository().syncQuiet(_studyLanguage));
      final data = await ref
          .read(subscriberDashboardRepositoryProvider)
          .fetch(studyLanguage: _studyLanguage);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar o início.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AppRole get _role =>
      ref.read(authControllerProvider).value?.role ?? AppRole.subscriber;

  void _openPath(String path) {
    context.push(path).then((_) {
      if (mounted) _load();
    });
  }

  void _openCoachAction(StudyCoachAction action) {
    final adapted = adaptLearnerRoute(action.route, _role);
    _openPath(adapted);
  }

  void _openAssignment(DashboardOpenAssignment assignment) {
    _openPath(switch (assignment.kind) {
      'vocab_review' => LearnerPaths.vocabulary(_role),
      'dictation_focus' => LearnerPaths.dictation(
        _role,
        query: Uri(
          queryParameters: {
            'lang': assignment.language,
            'focus': 'calibrated',
            if (assignment.cefr != null) 'cefr': assignment.cefr,
            if (assignment.focusTags.isNotEmpty)
              'tags': assignment.focusTags.join(','),
            if (assignment.targetCount != null)
              'count': '${assignment.targetCount}',
          },
        ).query,
      ),
      'read_text' ||
      'read_questions' ||
      'save_vocab_from_text' => LearnerPaths.library(_role),
      'production' => LearnerPaths.production(assignment.id),
      _ => LearnerPaths.coach(_role, lang: assignment.language),
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final firstName = user?.name.split(' ').first ?? '';
    final languages = user?.studyLanguages ?? const <String>[];
    final data = _data;

    return Scaffold(
      floatingActionButton: const NotebookFab(),
      appBar: AppBar(
        title: const Text('ConnectLang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Perfil',
            onPressed: () => _openPath(LearnerPaths.profile()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              firstName.isEmpty ? 'Olá!' : 'Olá, $firstName!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (languages.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final code in languages)
                    ChoiceChip(
                      label: Text(taughtLanguages[code] ?? code),
                      selected: _studyLanguage == code,
                      onSelected: (_) {
                        setState(() => _studyLanguage = code);
                        _load();
                      },
                    ),
                ],
              ),
            ],
            if (_loading && data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (data?.cefrBanner != null) ...[
                const SizedBox(height: 16),
                _CefrBannerCard(
                  banner: data!.cefrBanner!,
                  onOpen: () => _openPath(
                    LearnerPaths.placement(
                      _role,
                      lang: data.cefrBanner!.language,
                    ),
                  ),
                  onDismiss: () async {
                    await ref
                        .read(subscriberDashboardRepositoryProvider)
                        .dismissBanner(data.cefrBanner!);
                    await _load();
                  },
                ),
              ],
              if (data?.plan != null) ...[
                const SizedBox(height: 16),
                _TodayPlanCard(
                  plan: data!.plan!,
                  onOpenPlan: () => _openPath(
                    LearnerPaths.coach(_role, lang: _studyLanguage),
                  ),
                  onOpenAction: _openCoachAction,
                ),
              ],
              if (data != null && data.openAssignments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Para hoje',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final assignment in data.openAssignments)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.task_alt_outlined),
                      title: Text(assignment.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openAssignment(assignment),
                    ),
                  ),
              ],
              if ((data?.unreviewedAiNotes ?? 0) > 0) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: Text(
                      data!.unreviewedAiNotes == 1
                          ? '1 nota de IA pra revisitar'
                          : '${data.unreviewedAiNotes} notas de IA pra revisitar',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _openPath(LearnerPaths.notebook(_role, aiOnly: true)),
                  ),
                ),
              ],
              if (data != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        label: 'Palavras',
                        value: '${data.vocab.total}',
                        onTap: () => _openPath(LearnerPaths.vocabulary(_role)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        label: 'Pra revisar',
                        value: '${data.vocab.due}',
                        onTap: () => _openPath(LearnerPaths.vocabulary(_role)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Vocabulário recente',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          _openPath(LearnerPaths.vocabulary(_role)),
                      child: const Text('Ver tudo'),
                    ),
                  ],
                ),
                if (data.vocab.recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Você ainda não adicionou palavras.'),
                  )
                else
                  for (final word in data.vocab.recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(word.term),
                      subtitle: Text(word.translation),
                      trailing: Text(
                        taughtLanguages[word.language] ?? word.language,
                      ),
                      onTap: () => _openPath(LearnerPaths.vocabulary(_role)),
                    ),
                const SizedBox(height: 12),
                Text('Estudar', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ShortcutChip(
                      icon: Icons.style_outlined,
                      label: 'Vocabulário',
                      onTap: () => _openPath(LearnerPaths.vocabulary(_role)),
                    ),
                    _ShortcutChip(
                      icon: Icons.edit_note,
                      label: 'Caderno',
                      onTap: () => _openPath(LearnerPaths.notebook(_role)),
                    ),
                    _ShortcutChip(
                      icon: Icons.menu_book_outlined,
                      label: 'Biblioteca',
                      onTap: () => _openPath(LearnerPaths.library(_role)),
                    ),
                    _ShortcutChip(
                      icon: Icons.headphones,
                      label: 'Ditado',
                      onTap: () => _openPath(
                        LearnerPaths.dictation(
                          _role,
                          query: _studyLanguage == null
                              ? null
                              : 'lang=$_studyLanguage',
                        ),
                      ),
                    ),
                    _ShortcutChip(
                      icon: Icons.school_outlined,
                      label: 'Nivelamento',
                      onTap: () => _openPath(
                        LearnerPaths.placement(_role, lang: _studyLanguage),
                      ),
                    ),
                    _ShortcutChip(
                      icon: Icons.auto_awesome,
                      label: 'Study Coach',
                      onTap: () => _openPath(
                        LearnerPaths.coach(_role, lang: _studyLanguage),
                      ),
                    ),
                    _ShortcutChip(
                      icon: Icons.card_membership_outlined,
                      label: 'Assinatura',
                      onTap: () => _openPath(LearnerPaths.subscription),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Recados', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (data.announcements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nenhum recado no momento.'),
                  )
                else
                  for (final item in data.announcements)
                    Card(
                      child: ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          [
                            item.content,
                            '${item.createdAt.toLocal().day.toString().padLeft(2, '0')}/${item.createdAt.toLocal().month.toString().padLeft(2, '0')}/${item.createdAt.toLocal().year}',
                            if (item.authorName?.isNotEmpty == true)
                              item.authorName,
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                      ),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CefrBannerCard extends StatelessWidget {
  const _CefrBannerCard({
    required this.banner,
    required this.onOpen,
    required this.onDismiss,
  });

  final CefrBanner banner;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(banner.message),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: onOpen,
                  child: const Text('Fazer nivelamento'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Dispensar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard({
    required this.plan,
    required this.onOpenPlan,
    required this.onOpenAction,
  });

  final StudyCoachPlan plan;
  final VoidCallback onOpenPlan;
  final void Function(StudyCoachAction action) onOpenAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Plano de hoje',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: onOpenPlan,
                  child: const Text('Ver plano'),
                ),
              ],
            ),
            Text(plan.summary, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final action in plan.nextActions.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(action.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenAction(action),
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
