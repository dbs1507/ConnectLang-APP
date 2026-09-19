import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/learner_routes.dart';
import '../../app/learner_navigation.dart';
import '../../core/session/app_role.dart';
import '../../core/session/auth_controller.dart';
import '../../design_system/components/cards/app_surface.dart';
import '../../design_system/components/feedback/lia_mark.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../notebook/notebook_fab.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'models/study_coach_plan.dart';
import 'study_assignments_repository.dart';
import 'study_coach_controller.dart';

const _cardRadius = BorderRadius.all(Radius.circular(16));
const _tabRadius = BorderRadius.all(Radius.circular(12));
const _tabInnerRadius = BorderRadius.all(Radius.circular(9));

const _generateSteps = [
  'Lendo o seu progresso...',
  'Escolhendo o foco de hoje...',
  'Montando os próximos passos...',
];

/// Plano do dia da LIA — mesma hierarquia da home: marca, um resumo,
/// os passos, um CTA.
class StudyCoachHomePage extends ConsumerStatefulWidget {
  const StudyCoachHomePage({
    super.key,
    this.initialLanguage,
    this.initialPlan,
    this.initialHistory = const [],
    this.prefetched = false,
  });

  final String? initialLanguage;
  final StudyCoachPlan? initialPlan;
  final List<StudyCoachPlan> initialHistory;
  final bool prefetched;

  @override
  ConsumerState<StudyCoachHomePage> createState() => _StudyCoachHomePageState();
}

class _StudyCoachHomePageState extends ConsumerState<StudyCoachHomePage> {
  late String _language =
      (widget.initialLanguage != null && widget.initialLanguage!.isNotEmpty)
      ? widget.initialLanguage!
      : 'EN';
  late bool _loading = !widget.prefetched;
  bool _generating = false;
  bool _historyTab = false;
  String? _error;
  late StudyCoachPlan? _plan = widget.initialPlan;
  late List<StudyCoachPlan> _history = widget.initialHistory;
  StudyCoachPlan? _historyDetail;

  @override
  void initState() {
    super.initState();
    if (widget.prefetched) {
      unawaited(const StudyAssignmentsRepository().syncQuiet(_language));
      unawaited(_loadHistory());
    } else {
      _loadCached();
    }
  }

  Future<void> _loadCached() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = _languageOptions;
      if (options.isNotEmpty &&
          !options.any((entry) => entry.key == _language)) {
        _language = options.first.key;
      }
      unawaited(const StudyAssignmentsRepository().syncQuiet(_language));
      final repo = ref.read(studyCoachRepositoryProvider);
      final plan = await repo
          .fetchCachedPlan(_language)
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
      await _loadHistory();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar o plano.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ref
          .read(studyCoachRepositoryProvider)
          .fetchPlanHistory(_language)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyDetail = null;
      });
    } catch (_) {}
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
    unawaited(openLearnerRoute(context, ref, route: target, role: role));
  }

  List<MapEntry<String, String>> get _languageOptions {
    final codes =
        ref.read(authControllerProvider).value?.studyLanguages ?? const [];
    if (codes.isEmpty) return taughtLanguages.entries.toList();
    return [
      for (final code in codes)
        MapEntry(code, taughtLanguages[code] ?? code),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final busy = _generating || _loading;

    return Scaffold(
      backgroundColor: AppColors.liaSoft,
      floatingActionButton: const NotebookFab(),
      appBar: AppBar(
        title: const Text('LIA'),
        backgroundColor: AppColors.liaSoft,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCached,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              96,
            ),
            children: [
              Text('Idioma', style: textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              AppSurface(
                borderRadius: _cardRadius,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: ValueKey(_language),
                    value: _language,
                    isExpanded: true,
                    icon: const Icon(
                      LucideIcons.chevron_down,
                      color: AppColors.foreground,
                    ),
                    items: [
                      for (final entry in _languageOptions)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            style: textTheme.bodyLarge?.copyWith(
                              color: AppColors.heading,
                            ),
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _language = value;
                              _historyDetail = null;
                            });
                            _loadCached();
                          },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _CoachTabs(
                history: _historyTab,
                onChanged: (history) => setState(() {
                  _historyTab = history;
                  _historyDetail = null;
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_historyTab)
                ..._historyBody(context)
              else ...[
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.destructive,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_generating)
                  const _GeneratingPlan()
                else if (_plan == null)
                  AppSurface(
                    borderRadius: _cardRadius,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Nenhum plano ainda pra esse idioma. Gere um plano personalizado com a LIA.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.heading,
                      ),
                    ),
                  )
                else
                  _PlanCard(plan: _plan!, onOpenAction: _openRoute),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.astroid, size: 18),
                    label: Text(
                      _plan == null ? 'Gerar plano' : 'Atualizar plano',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _historyBody(BuildContext context) {
    if (_historyDetail != null) {
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _historyDetail = null),
            icon: const Icon(LucideIcons.arrow_left, size: 18),
            label: const Text('Voltar ao histórico'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PlanCard(plan: _historyDetail!, onOpenAction: _openRoute),
      ];
    }
    if (_history.isEmpty) {
      return [
        AppSurface(
          borderRadius: _cardRadius,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Ainda não há planos anteriores neste idioma.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ];
    }
    return [
      for (final plan in _history) ...[
        AppSurface(
          borderRadius: _cardRadius,
          padding: EdgeInsets.zero,
          onTap: () => setState(() => _historyDetail = plan),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.heading,
                        ),
                      ),
                      if (_historyMeta(plan).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _historyMeta(plan),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
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
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  String _historyMeta(StudyCoachPlan plan) {
    return [
      if (plan.planDate != null) plan.planDate!,
      if (plan.generatedAt != null)
        '${plan.generatedAt!.day.toString().padLeft(2, '0')}/${plan.generatedAt!.month.toString().padLeft(2, '0')}/${plan.generatedAt!.year}',
    ].join(' · ');
  }
}

class _CoachTabs extends StatelessWidget {
  const _CoachTabs({required this.history, required this.onChanged});

  final bool history;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: _tabRadius,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Expanded(
              child: _CoachTab(
                label: 'Hoje',
                selected: !history,
                onTap: () => onChanged(false),
              ),
            ),
            Expanded(
              child: _CoachTab(
                label: 'Histórico',
                selected: history,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachTab extends StatelessWidget {
  const _CoachTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _tabInnerRadius,
        splashColor: AppColors.buttonBlack.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.buttonBlack : Colors.transparent,
            borderRadius: _tabInnerRadius,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: selected ? Colors.white : AppColors.buttonBlack,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneratingPlan extends StatelessWidget {
  const _GeneratingPlan();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          LiaPulseMark(size: 64, iconSize: 26),
          SizedBox(height: AppSpacing.lg),
          _RotatingHint(messages: _generateSteps),
        ],
      ),
    );
  }
}

class _RotatingHint extends StatefulWidget {
  const _RotatingHint({required this.messages});

  final List<String> messages;

  @override
  State<_RotatingHint> createState() => _RotatingHintState();
}

class _RotatingHintState extends State<_RotatingHint> {
  var _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.messages.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (!mounted) return;
        setState(() => _index = (_index + 1) % widget.messages.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: Align(
          key: ValueKey(_index),
          alignment: Alignment.topCenter,
          child: Text(
            widget.messages[_index],
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.foreground,
            ),
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.lia,
            borderRadius: _cardRadius,
            boxShadow: [
              BoxShadow(
                color: AppColors.lia.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const LiaBurstIcon(size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'LIA',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.heading,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    plan.summary,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.heading,
                      height: 1.4,
                    ),
                  ),
                  if (plan.focusAreas.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      plan.focusAreas.join(' · '),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.heading.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                  if (plan.evidence.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _WhyPlan(evidence: plan.evidence),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Próximos passos',
          style: textTheme.titleMedium?.copyWith(color: AppColors.heading),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final action in plan.nextActions) ...[
          _ActionRow(
            action: action,
            onTap: () => onOpenAction(action.route, type: action.type),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _WhyPlan extends StatefulWidget {
  const _WhyPlan({required this.evidence});

  final List<StudyCoachEvidenceItem> evidence;

  @override
  State<_WhyPlan> createState() => _WhyPlanState();
}

class _WhyPlanState extends State<_WhyPlan> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Por que esse plano',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _open ? LucideIcons.chevron_up : LucideIcons.chevron_down,
                size: 16,
                color: AppColors.heading,
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in widget.evidence)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            '·  ${item.text}',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.onTap});

  final StudyCoachAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _cardRadius,
        child: Ink(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: _cardRadius,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.border),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      AppColors.background,
                      AppColors.terracotta,
                      0.18,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconForType(action.type),
                    size: 20,
                    color: AppColors.terracotta,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.heading,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (action.reason.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          action.reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  LucideIcons.chevron_right,
                  size: 18,
                  color: AppColors.navText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconForType(StudyCoachActionType type) {
  return switch (type) {
    StudyCoachActionType.dictationPractice ||
    StudyCoachActionType.reviewMistakes => LucideIcons.headphones,
    StudyCoachActionType.vocabularyReview ||
    StudyCoachActionType.addWords => LucideIcons.square_stack,
    StudyCoachActionType.readText => LucideIcons.book,
    StudyCoachActionType.notebookReview ||
    StudyCoachActionType.aiNotesReview => LucideIcons.notebook_pen,
    StudyCoachActionType.productionTask => LucideIcons.file_pen,
    StudyCoachActionType.unknown => LucideIcons.astroid,
  };
}
