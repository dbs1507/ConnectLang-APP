import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictation/dictation_home_page.dart';
import '../library/library_list_page.dart';
import '../notebook/notebook_list_page.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import '../vocabulary/vocabulary_list_page.dart';
import 'models/study_coach_plan.dart';
import 'production_demand_page.dart';
import 'study_coach_controller.dart';
import 'study_coach_repository.dart';

/// Espelha `src/pages/student/StudyCoachPage.tsx`, reduzido: só a aba "hoje"
/// (`PlanFocusCard`/`PlanReasonsCard`), sem histórico de planos, sem o painel
/// unificado de assignments (`LiaUnifiedTodayCard`) — os `nextActions` do
/// plano já cobrem o essencial.
class StudyCoachHomePage extends ConsumerStatefulWidget {
  const StudyCoachHomePage({super.key});

  @override
  ConsumerState<StudyCoachHomePage> createState() => _StudyCoachHomePageState();
}

class _StudyCoachHomePageState extends ConsumerState<StudyCoachHomePage> {
  String _language = 'EN';
  bool _loading = true;
  bool _generating = false;
  String? _error;
  StudyCoachPlan? _plan;

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
      final plan = await ref.read(studyCoachRepositoryProvider).fetchCachedPlan(_language);
      if (!mounted) return;
      setState(() => _plan = plan);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível carregar o plano.');
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
      final plan = await ref.read(studyCoachRepositoryProvider).generatePlan(_language);
      if (!mounted) return;
      setState(() => _plan = plan);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível gerar o plano agora. Tente novamente em instantes.');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _openRoute(String route, {required StudyCoachActionType type}) {
    Widget? page;
    switch (type) {
      case StudyCoachActionType.vocabularyReview:
      case StudyCoachActionType.addWords:
        page = const VocabularyListPage();
      case StudyCoachActionType.dictationPractice:
      case StudyCoachActionType.reviewMistakes:
        page = const DictationHomePage();
      case StudyCoachActionType.readText:
        page = const LibraryListPage();
      case StudyCoachActionType.notebookReview:
      case StudyCoachActionType.aiNotesReview:
        page = const NotebookListPage();
      case StudyCoachActionType.productionTask:
        final id = productionAssignmentIdFromRoute(route);
        if (id != null) page = ProductionDemandPage(assignmentId: id);
      case StudyCoachActionType.unknown:
        break;
    }
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Essa ação ainda não está disponível no app.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Coach')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCached,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Idioma'),
                items: [
                  for (final entry in taughtLanguages.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
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
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                if (_plan == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nenhum plano ainda pra esse idioma. Gere um plano personalizado com a LIA.'),
                  )
                else
                  _PlanCard(plan: _plan!, onOpenAction: _openRoute),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_plan == null ? 'Gerar plano' : 'Atualizar plano'),
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
  final void Function(String route, {required StudyCoachActionType type}) onOpenAction;

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
                    Icon(Icons.auto_awesome, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('LIA', style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(plan.summary, style: Theme.of(context).textTheme.titleMedium),
                if (plan.focusAreas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(plan.focusAreas.join(' · '), style: Theme.of(context).textTheme.bodySmall),
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
          Text('Por que esse plano', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final item in plan.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('•  ${item.text}', style: Theme.of(context).textTheme.bodyMedium),
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
