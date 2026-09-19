import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/learner_routes.dart';
import '../../app/learner_navigation.dart';
import '../../core/session/app_role.dart';
import '../../core/session/auth_controller.dart';
import '../../design_system/components/cards/app_surface.dart';
import '../../design_system/components/feedback/lia_mark.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../../design_system/theme/app_typography.dart';
import '../notebook/notebook_fab.dart';
import '../study_coach/models/study_coach_plan.dart';
import '../study_coach/study_assignments_repository.dart';
import 'subscriber_dashboard_page.dart'
    show subscriberDashboardRepositoryProvider;
import 'subscriber_dashboard_repository.dart';

const _homeCardRadius = BorderRadius.all(Radius.circular(16));
const _stepIconWell = Color(0xFFF6EFEA);

/// Home do assinante — item 1 da bottom nav é "o que eu faço agora"
/// (Headspace/Babbel). LIA entra pelo chip no topo. A barra em si vive no
/// [SubscriberTabShell], para não sumir ao trocar de aba.
class SubscriberHomeShell extends ConsumerStatefulWidget {
  const SubscriberHomeShell({super.key});

  @override
  ConsumerState<SubscriberHomeShell> createState() =>
      _SubscriberHomeShellState();
}

class _TodayItem {
  const _TodayItem({
    required this.title,
    required this.subtitle,
    required this.onOpen,
    required this.icon,
    required this.kindLabel,
    this.liaAction,
  });

  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final IconData icon;
  final String kindLabel;
  final StudyCoachAction? liaAction;
}

class _SubscriberHomeShellState extends ConsumerState<SubscriberHomeShell> {
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

  void _openLia() {
    unawaited(
      openLearnerRoute(
        context,
        ref,
        route: LearnerPaths.coach(_role, lang: _studyLanguage),
        role: _role,
        seedCoachPlan: _data?.plan,
      ).then((_) {
        if (mounted) _load();
      }),
    );
  }

  void _openTab(String path) {
    context.go(path);
  }

  void _openCoachAction(StudyCoachAction action) {
    unawaited(
      openLearnerRoute(
        context,
        ref,
        route: action.route,
        role: _role,
      ).then((_) {
        if (mounted) _load();
      }),
    );
  }

  void _openAssignment(DashboardOpenAssignment assignment) {
    final route = switch (assignment.kind) {
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
      'read_text' || 'read_questions' || 'save_vocab_from_text' =>
        LearnerPaths.library(_role, textId: assignment.textId),
      'production' => LearnerPaths.production(assignment.id),
      _ => LearnerPaths.coach(_role, lang: assignment.language),
    };
    unawaited(
      openLearnerRoute(context, ref, route: route, role: _role).then((_) {
        if (mounted) _load();
      }),
    );
  }

  List<_TodayItem> _buildQueue(SubscriberDashboardData data) {
    return [
      for (final action in data.plan?.nextActions ?? const [])
        _TodayItem(
          title: action.title,
          subtitle: action.reason,
          onOpen: () => _openCoachAction(action),
          icon: _iconForAction(action.type),
          kindLabel: _labelForAction(action.type),
          liaAction: action,
        ),
      for (final assignment in data.openAssignments)
        _TodayItem(
          title: assignment.label,
          subtitle: 'Da sua fila de hoje',
          onOpen: () => _openAssignment(assignment),
          icon: _iconForAssignment(assignment.kind),
          kindLabel: _labelForAssignment(assignment.kind),
        ),
      if (data.unreviewedAiNotes > 0)
        _TodayItem(
          title: data.unreviewedAiNotes == 1
              ? '1 nota de IA pra revisitar'
              : '${data.unreviewedAiNotes} notas de IA pra revisitar',
          subtitle: 'Caderno',
          onOpen: () => _openPath(LearnerPaths.notebook(_role, aiOnly: true)),
          icon: LucideIcons.astroid,
          kindLabel: 'CADERNO',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: false,
      floatingActionButton: const NotebookFab(),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    final user = ref.watch(authControllerProvider).value;
    final firstName = user?.name.split(' ').first ?? '';
    final data = _data;

    if (_loading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final queue = data == null ? const <_TodayItem>[] : _buildQueue(data);
    final plan = data?.plan;
    final now = DateTime.now();
    final headline = (plan?.summary.isNotEmpty ?? false)
        ? plan!.summary
        : (queue.isEmpty
              ? 'Vamos começar'
              : queue.first.title);
    final body = queue.isEmpty
        ? 'Faça o nivelamento pra LIA montar seu primeiro plano de estudo.'
        : (queue.first.subtitle.isNotEmpty
              ? queue.first.subtitle
              : (plan?.focusAreas.isNotEmpty ?? false)
              ? plan!.focusAreas.first
              : '');
    final eyebrow = queue.isEmpty
        ? 'HOJE'
        : 'HOJE · ${queue.first.kindLabel}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      children: [
        _HomeGreeting(
          dateLabel: _homeDateLabel(now),
          title: firstName.isEmpty
              ? _homeGreeting(now)
              : '${_homeGreeting(now)}, $firstName',
          onOpenLia: _openLia,
        ),
        const SizedBox(height: AppSpacing.xl),

        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (data?.cefrBanner != null) ...[
          _CefrBanner(
            message: data!.cefrBanner!.message,
            onOpen: () => _openPath(
              LearnerPaths.placement(_role, lang: data.cefrBanner!.language),
            ),
            onDismiss: () async {
              await ref
                  .read(subscriberDashboardRepositoryProvider)
                  .dismissBanner(data.cefrBanner!);
              await _load();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        _HeroCard(
          eyebrow: eyebrow,
          headline: headline,
          body: body,
          ctaLabel: queue.isEmpty ? 'Fazer nivelamento' : 'Começar',
          onStart: queue.isEmpty
              ? () => _openPath(
                  LearnerPaths.placement(_role, lang: _studyLanguage),
                )
              : queue.first.onOpen,
        ),

        if (queue.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Seus próximos passos',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _NextStepsCard(items: queue),
        ],

        if (data != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _VocabCard(
            total: data.vocab.total,
            due: data.vocab.due,
            onOpen: () => _openTab(LearnerPaths.vocabulary(_role)),
          ),
        ],
      ],
    );
  }
}

IconData _iconForAction(StudyCoachActionType type) {
  return switch (type) {
    StudyCoachActionType.vocabularyReview ||
    StudyCoachActionType.addWords => LucideIcons.list,
    StudyCoachActionType.dictationPractice ||
    StudyCoachActionType.reviewMistakes => LucideIcons.mic,
    StudyCoachActionType.readText => LucideIcons.type,
    StudyCoachActionType.notebookReview ||
    StudyCoachActionType.aiNotesReview => LucideIcons.notebook_pen,
    StudyCoachActionType.productionTask => LucideIcons.file_pen,
    StudyCoachActionType.unknown => LucideIcons.astroid,
  };
}

String _labelForAction(StudyCoachActionType type) {
  return switch (type) {
    StudyCoachActionType.vocabularyReview ||
    StudyCoachActionType.addWords => 'VOCABULÁRIO',
    StudyCoachActionType.dictationPractice => 'DITADO',
    StudyCoachActionType.reviewMistakes => 'REVISÃO',
    StudyCoachActionType.readText => 'LEITURA',
    StudyCoachActionType.notebookReview ||
    StudyCoachActionType.aiNotesReview => 'CADERNO',
    StudyCoachActionType.productionTask => 'PRODUÇÃO',
    StudyCoachActionType.unknown => 'ESTUDO',
  };
}

IconData _iconForAssignment(String kind) {
  return switch (kind) {
    'vocab_review' => LucideIcons.list,
    'dictation_focus' => LucideIcons.mic,
    'read_text' || 'read_questions' || 'save_vocab_from_text' =>
      LucideIcons.type,
    'production' => LucideIcons.file_pen,
    _ => LucideIcons.astroid,
  };
}

String _labelForAssignment(String kind) {
  return switch (kind) {
    'vocab_review' => 'VOCABULÁRIO',
    'dictation_focus' => 'DITADO',
    'read_text' || 'read_questions' || 'save_vocab_from_text' => 'LEITURA',
    'production' => 'PRODUÇÃO',
    _ => 'ESTUDO',
  };
}

String _homeGreeting(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Bom dia';
  if (hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

String _homeDateLabel(DateTime now) {
  const weekdays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${weekdays[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}';
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({
    required this.dateLabel,
    required this.title,
    required this.onOpenLia,
  });

  final String dateLabel;
  final String title;
  final VoidCallback onOpenLia;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel,
          style: textTheme.bodySmall?.copyWith(color: AppColors.foreground),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(title, style: textTheme.displaySmall),
            ),
            const SizedBox(width: AppSpacing.md),
            LiaChip(onTap: onOpenLia),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.ctaLabel,
    required this.onStart,
  });

  final String eyebrow;
  final String headline;
  final String body;
  final String ctaLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.heading,
      borderRadius: _homeCardRadius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: AppTypography.microLabel.copyWith(
                color: AppColors.primarySoft,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              headline,
              style: textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                height: 1.35,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                body,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onStart,
              child: Text(ctaLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard({required this.items});

  final List<_TodayItem> items;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      borderRadius: _homeCardRadius,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _NextStepRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _NextStepRow extends StatelessWidget {
  const _NextStepRow({required this.item});

  final _TodayItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _stepIconWell,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 18,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              LucideIcons.chevron_right,
              size: 18,
              color: AppColors.navText,
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabCard extends StatelessWidget {
  const _VocabCard({
    required this.total,
    required this.due,
    required this.onOpen,
  });

  final int total;
  final int due;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppSurface(
      borderRadius: _homeCardRadius,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Seu vocabulário',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.heading,
                  ),
                ),
              ),
              Text(
                due == 0 ? 'Em dia' : '$due pra revisar',
                style: textTheme.labelMedium?.copyWith(
                  color: due == 0 ? AppColors.success : AppColors.terracotta,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$total palavra${total == 1 ? '' : 's'} no caderno',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: Text(due > 0 ? 'Revisar agora' : 'Abrir vocabulário'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CefrBanner extends StatelessWidget {
  const _CefrBanner({
    required this.message,
    required this.onOpen,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      borderRadius: _homeCardRadius,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton(
                onPressed: onOpen,
                child: const Text('Fazer nivelamento'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Dispensar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
