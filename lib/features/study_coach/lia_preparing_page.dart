import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/feedback/lia_mark.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../dictation/dictation_controller.dart';
import '../dictation/dictation_session_page.dart';
import '../dictation/models/dictation_next_result.dart';
import '../library/library_controller.dart';
import '../library/text_reading_page.dart';
import '../vocabulary/flashcard_practice_page.dart';
import 'models/study_coach_plan.dart';
import 'production_demand_page.dart';
import 'study_assignments_repository.dart';
import 'study_coach_controller.dart';
import 'study_coach_home_page.dart';
import 'study_coach_repository.dart';

enum LiaLaunchKind {
  dictation,
  reading,
  vocabulary,
  production,
  notebook,
  coach,
  other;

  String get message => switch (this) {
    dictation => 'Carregando ditado gerado pela LIA…',
    reading => 'Carregando o texto da LIA…',
    vocabulary => 'Carregando a revisão de vocabulário…',
    production => 'Carregando a tarefa de produção…',
    notebook => 'Carregando as notas da LIA…',
    coach => 'Abrindo a LIA…',
    other => 'Carregando o que a LIA preparou…',
  };
}

/// Tela cheia enquanto a LIA monta o próximo passo — o aluno não vê a
/// home de Ditado/Biblioteca vazia antes do conteúdo ficar pronto.
class LiaPreparingPage extends ConsumerStatefulWidget {
  const LiaPreparingPage({
    super.key,
    required this.kind,
    required this.route,
    this.onReadyInShell,
    this.onRevealTab,
    this.seedPlan,
  });

  final LiaLaunchKind kind;
  final String route;
  final StudyCoachPlan? seedPlan;

  /// Troca a aba de baixo (Biblioteca/Ditado/Vocabulário) antes de abrir
  /// o conteúdo, pra o voltar cair no lugar certo.
  final VoidCallback? onRevealTab;

  /// Se preenchido, a espera fecha em tela cheia e a página pronta abre
  /// no navigator das abas — a barra de atalhos continua visível.
  final void Function(Widget page)? onReadyInShell;

  @override
  ConsumerState<LiaPreparingPage> createState() => _LiaPreparingPageState();
}

class _LiaPreparingPageState extends ConsumerState<LiaPreparingPage> {
  String? _error;
  var _cancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Duration get _budget => switch (widget.kind) {
    LiaLaunchKind.reading => const Duration(seconds: 6),
    LiaLaunchKind.vocabulary => const Duration(seconds: 4),
    LiaLaunchKind.coach => const Duration(seconds: 3),
    _ => const Duration(seconds: 4),
  };

  Future<void> _run() async {
    final started = DateTime.now();
    try {
      final page = widget.kind == LiaLaunchKind.dictation
          ? await _prepare()
          : await _prepare().timeout(_budget);
      await _ensureMinDelay(started);
      if (!mounted || _cancelled) return;
      _deliver(page);
    } on TimeoutException {
      await _ensureMinDelay(started);
      if (!mounted || _cancelled) return;
      _failOrFallback();
    } catch (error) {
      await _ensureMinDelay(started);
      if (!mounted || _cancelled) return;
      if (error is StateError && error.message == 'cancelled') return;
      _failOrFallback();
    }
  }

  void _failOrFallback() {
    if (widget.kind == LiaLaunchKind.dictation) {
      setState(
        () => _error = 'Não foi possível montar o ditado agora. Tente de novo.',
      );
      return;
    }
    _openNamedRoute();
  }

  void _deliver(Widget? page) {
    if (page == null || widget.kind == LiaLaunchKind.reading) {
      _openNamedRoute();
      return;
    }
    if (widget.onReadyInShell != null) {
      _handoffToShell(page);
      return;
    }
    _replaceWith(page);
    // Espera um frame extra: goBranch() reconstrói o navigator raiz via
    // GoRouter, e chamar isso no mesmo lote de postFrameCallback do
    // pushReplacement colide com o lock do Navigator (_debugLocked).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onRevealTab?.call();
      });
    });
  }

  Future<void> _ensureMinDelay(DateTime started) async {
    const min = Duration(milliseconds: 500);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < min) {
      await Future<void>.delayed(min - elapsed);
    }
  }

  Future<Widget?> _prepare() async {
    switch (widget.kind) {
      case LiaLaunchKind.dictation:
        return _openDictation();
      case LiaLaunchKind.reading:
        return _openReading();
      case LiaLaunchKind.vocabulary:
        return _openVocabulary();
      case LiaLaunchKind.production:
        return _openProduction();
      case LiaLaunchKind.notebook:
        return null;
      case LiaLaunchKind.coach:
        return _openCoach();
      case LiaLaunchKind.other:
        throw StateError('unsupported');
    }
  }

  Future<Widget> _openDictation() async {
    final args = DictationLaunchArgs.fromRoute(
      widget.route,
      fallbackLanguage: 'EN',
    );
    final items = await ref
        .read(dictationRepositoryProvider)
        .fetchFreeItems(
          language: args.language,
          cefr: args.cefr,
          focusTags: args.focusTags,
          limit: args.sessionSize,
        )
        .timeout(const Duration(seconds: 4));
    if (_cancelled) throw StateError('cancelled');
    if (items.isEmpty) throw StateError('empty');

    return DictationSessionPage(
      items: items,
      calibrated: args.autoStartCalibrated,
      focusTags: args.focusTags,
    );
  }

  Future<Widget> _openReading() async {
    final uri = Uri.parse('https://app${widget.route}');
    final textId =
        uri.queryParameters['text_id'] ?? uri.queryParameters['textId'];
    if (textId == null || textId.isEmpty) throw StateError('missing text');
    final text = await ref
        .read(libraryRepositoryProvider)
        .fetchTextById(textId)
        .timeout(const Duration(seconds: 5));
    if (_cancelled) throw StateError('cancelled');
    if (text == null) throw StateError('missing text');
    return TextReadingPage(text: text);
  }

  Future<Widget> _openVocabulary() async {
    return const FlashcardPracticePage();
  }

  Future<Widget> _openCoach() async {
    final uri = Uri.parse('https://app${widget.route}');
    final langRaw = (uri.queryParameters['lang'] ?? 'EN').toUpperCase();
    final language = langRaw.isEmpty ? 'EN' : langRaw;
    unawaited(const StudyAssignmentsRepository().syncQuiet(language));

    // Histórico fica pra depois — a tela amarela só precisa do plano do dia.
    StudyCoachPlan? plan = widget.seedPlan;
    var ready = plan != null;
    if (!ready) {
      try {
        plan = await ref
            .read(studyCoachRepositoryProvider)
            .fetchCachedPlan(language)
            .timeout(const Duration(seconds: 3));
        ready = true;
      } on TimeoutException {
        ready = false;
      }
    }
    if (_cancelled) throw StateError('cancelled');
    return StudyCoachHomePage(
      initialLanguage: language,
      initialPlan: plan,
      initialHistory: const [],
      prefetched: ready,
    );
  }

  Future<Widget> _openProduction() async {
    final id = productionAssignmentIdFromRoute(widget.route);
    if (id == null || id.isEmpty) throw StateError('missing assignment');
    return ProductionDemandPage(assignmentId: id);
  }

  void _openNamedRoute() {
    if (!mounted || _cancelled) return;
    final router = GoRouter.of(context);
    final route = widget.route;
    final overlayNav = Navigator.of(context, rootNavigator: true);
    if (overlayNav.canPop()) overlayNav.pop();
    // Mesmo motivo do onRevealTab acima: router.go() reconstrói o navigator
    // raiz, então precisa de um frame de distância do pop() imperativo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.go(route);
      });
    });
  }

  void _handoffToShell(Widget page) {
    if (!mounted || _cancelled) return;
    final overlayNav = Navigator.of(context, rootNavigator: true);
    try {
      widget.onReadyInShell!(page);
    } catch (_) {
      _replaceWith(page);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (overlayNav.mounted && overlayNav.canPop()) overlayNav.pop();
    });
  }

  void _replaceWith(Widget page) {
    if (!mounted || _cancelled) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasError = _error != null;
    return Scaffold(
      backgroundColor: AppColors.yellowPale,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Cancelar',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(LucideIcons.x),
                ),
              ),
              const Spacer(),
              LiaFigure(pulse: !hasError),
              if (hasError) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Você pode voltar e tentar de novo.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Voltar'),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
