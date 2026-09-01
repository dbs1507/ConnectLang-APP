import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/learner_routes.dart';
import '../../core/session/app_role.dart';
import '../../core/session/auth_controller.dart';
import '../notebook/notebook_fab.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'models/study_coach_plan.dart';
import 'study_assignments_repository.dart';
import 'study_coach_controller.dart';

/// Espelha `src/pages/student/StudyCoachPage.tsx`, reduzido: só a aba "hoje"
/// (`PlanFocusCard`/`PlanReasonsCard`), sem histórico de planos, sem o painel
/// unificado de assignments (`LiaUnifiedTodayCard`) — os `nextActions` do
/// plano já cobrem o essencial.
class StudyCoachHomePage extends ConsumerStatefulWidget {
  const StudyCoachHomePage({super.key, this.initialLanguage});

  final String? initialLanguage;

  @override
  ConsumerState<StudyCoachHomePage> createState() => _StudyCoachHomePageState();
}

class _StudyCoachHomePageState extends ConsumerState<StudyCoachHomePage> {
  late String _language = widget.initialLanguage ?? 'EN';
  bool _loading = true;
  bool _generating = false;
  bool _historyTab = false;
  String? _error;
  StudyCoachPlan? _plan;
  List<StudyCoachPlan> _history = const [];
  StudyCoachPlan? _historyDetail;

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  Future<void> _loadCached() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      unawaited(const StudyAssignmentsRepository().syncQuiet(_language));
      final plan = await ref
          .read(studyCoachRepositoryProvider)
          .fetchCachedPlan(_language);
      final history = await ref
          .read(studyCoachRepositoryProvider)
          .fetchPlanHistory(_language);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _history = history;
        _historyDetail = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar o plano.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final plan = await ref
          .read(studyCoachRepositoryProvider)
          .generatePlan(_language);
      final history = await ref
          .read(studyCoachRepositoryProvider)
          .fetchPlanHistory(_language);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _history = history;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível gerar o plano agora. Tente novamente em instantes.',
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _openRoute(String route, {required StudyCoachActionType type}) {
    final role =
        ref.read(authControllerProvider).value?.role ?? AppRole.subscriber;
    var target = adaptLearnerRoute(route, role);
    if (type == StudyCoachActionType.aiNotesReview &&
        !target.contains('tab=')) {
      target = LearnerPaths.notebook(role, aiOnly: true);
    }
    if (!target.startsWith('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Essa ação ainda não está disponível no app.'),
        ),
      );
      return;
    }
    context.push(target);
  }

  List<Widget> _historyBody(BuildContext context) {
    if (_historyDetail != null) {
      return [
        TextButton.icon(
          onPressed: () => setState(() => _historyDetail = null),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Voltar ao histórico'),
        ),
        _PlanCard(plan: _historyDetail!, onOpenAction: _openRoute),
      ];
    }
    if (_history.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Ainda não há planos anteriores neste idioma.'),
        ),
      ];
    }
    return [
      for (final plan in _history)
        Card(
          child: ListTile(
            title: Text(
              plan.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (plan.planDate != null) plan.planDate!,
                if (plan.generatedAt != null)
                  '${plan.generatedAt!.day.toString().padLeft(2, '0')}/${plan.generatedAt!.month.toString().padLeft(2, '0')}/${plan.generatedAt!.year}',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _historyDetail = plan),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const NotebookFab(),
      appBar: AppBar(title: const Text('Study Coach')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCached,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(_language),
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Idioma'),
                items: [
                  for (final entry in taughtLanguages.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (_generating || _loading)
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _language = value);
                        _loadCached();
                      },
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Hoje')),
                  ButtonSegment(value: true, label: Text('Histórico')),
                ],
                selected: {_historyTab},
                onSelectionChanged: (value) => setState(() {
                  _historyTab = value.first;
                  _historyDetail = null;
                }),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_historyTab)
                ..._historyBody(context)
              else ...[
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_plan == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nenhum plano ainda pra esse idioma. Gere um plano personalizado com a LIA.',
                    ),
                  )
                else
                  _PlanCard(plan: _plan!, onOpenAction: _openRoute),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _plan == null ? 'Gerar plano' : 'Atualizar plano',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onOpenAction});

  final StudyCoachPlan plan;
  final void Function(String route, {required StudyCoachActionType type})
  onOpenAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
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
                    Text('LIA', style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  plan.summary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (plan.focusAreas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    plan.focusAreas.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Próximos passos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final action in plan.nextActions)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(_iconForType(action.type)),
              title: Text(action.title),
              subtitle: Text(action.reason),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenAction(action.route, type: action.type),
            ),
          ),
        if (plan.evidence.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Por que esse plano',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final item in plan.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '•  ${item.text}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ],
    );
  }

  IconData _iconForType(StudyCoachActionType type) {
    switch (type) {
      case StudyCoachActionType.dictationPractice:
      case StudyCoachActionType.reviewMistakes:
        return Icons.headphones;
      case StudyCoachActionType.vocabularyReview:
      case StudyCoachActionType.addWords:
        return Icons.style_outlined;
      case StudyCoachActionType.readText:
        return Icons.menu_book_outlined;
      case StudyCoachActionType.notebookReview:
      case StudyCoachActionType.aiNotesReview:
        return Icons.edit_note;
      case StudyCoachActionType.productionTask:
        return Icons.edit_document;
      case StudyCoachActionType.unknown:
        return Icons.auto_awesome;
    }
  }
}
