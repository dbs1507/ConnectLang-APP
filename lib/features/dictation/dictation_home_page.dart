import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/app_role.dart';
import '../../core/session/auth_controller.dart';
import '../../design_system/components/cards/app_surface.dart';
import '../../design_system/components/navigation/app_choice_chips.dart';
import '../../design_system/components/navigation/app_filter_menu.dart';
import '../../design_system/components/navigation/app_page_header.dart';
import '../../design_system/components/navigation/app_text_tabs.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../notebook/notebook_fab.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'dictation_controller.dart';
import 'dictation_session_page.dart';
import 'models/dictation_next_result.dart';
import 'models/dictation_recent_session.dart';

class DictationHomePage extends ConsumerStatefulWidget {
  const DictationHomePage({
    super.key,
    this.initialLanguage,
    this.initialCefr,
    this.initialFocusTags = const [],
    this.initialCount,
    this.autoStartCalibrated = false,
  });

  final String? initialLanguage;
  final String? initialCefr;
  final List<String> initialFocusTags;
  final int? initialCount;
  final bool autoStartCalibrated;

  factory DictationHomePage.fromRoute(
    String route, {
    String? fallbackLanguage,
  }) {
    final args = DictationLaunchArgs.fromRoute(
      route,
      fallbackLanguage: fallbackLanguage ?? 'EN',
    );
    return DictationHomePage(
      initialLanguage: args.language,
      initialCefr: args.cefr,
      initialFocusTags: args.focusTags,
      initialCount: args.sessionSize,
      autoStartCalibrated: args.autoStartCalibrated,
    );
  }

  @override
  ConsumerState<DictationHomePage> createState() => _DictationHomePageState();
}

const _sessionSizeOptions = [5, 10, 15, 20];
const _cardRadius = BorderRadius.all(Radius.circular(16));
const _cardPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  AppSpacing.lg,
  AppSpacing.xl,
  AppSpacing.xl,
);

int _nearestSessionSize(int value) {
  return _sessionSizeOptions.reduce(
    (a, b) => (a - value).abs() <= (b - value).abs() ? a : b,
  );
}

class _DictationHomePageState extends ConsumerState<DictationHomePage> {
  late String _language = widget.initialLanguage ?? 'EN';
  late int _sessionSize = _nearestSessionSize(widget.initialCount ?? 10);
  late bool _calibrated = widget.autoStartCalibrated;
  late final String? _cefr = widget.initialCefr;
  late final List<String> _focusTags = widget.initialFocusTags;
  bool _loading = false;
  String? _error;
  String? _focusHeadline;
  List<DictationRecentSession> _recent = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLanguage();
      unawaited(_loadRecent());
      if (widget.autoStartCalibrated) _start();
    });
  }

  List<MapEntry<String, String>> get _languageOptions {
    final codes =
        ref.read(authControllerProvider).value?.studyLanguages ?? const [];
    if (codes.isEmpty) return taughtLanguages.entries.toList();
    return [
      for (final code in codes) MapEntry(code, taughtLanguages[code] ?? code),
    ];
  }

  void _ensureLanguage() {
    final options = _languageOptions;
    if (options.isEmpty) return;
    if (options.any((entry) => entry.key == _language)) return;
    setState(() => _language = options.first.key);
  }

  Future<void> _loadRecent() async {
    try {
      final sessions = await ref
          .read(dictationRepositoryProvider)
          .fetchRecentSessions();
      if (mounted) setState(() => _recent = sessions);
    } catch (_) {}
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _focusHeadline = null;
    });
    try {
      final items = await ref
          .read(dictationRepositoryProvider)
          .fetchFreeItems(
            language: _language,
            cefr: _cefr,
            focusTags: _calibrated ? _focusTags : const [],
            limit: _sessionSize,
          )
          .timeout(const Duration(seconds: 4));
      if (!mounted) return;
      if (items.isEmpty) {
        setState(
          () => _error = 'Não há frases de ditado pra esse idioma ainda.',
        );
        return;
      }
      if (_calibrated && _focusTags.isNotEmpty) {
        setState(() => _focusHeadline = _focusTags.first);
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DictationSessionPage(
            items: items,
            calibrated: _calibrated,
            focusTags: _focusTags,
          ),
        ),
      );
      await _loadRecent();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível carregar as frases. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isSubscriber =
        ref.watch(authControllerProvider).value?.role == AppRole.subscriber;
    final languageName = taughtLanguages[_language] ?? _language;
    final modeCopy = _calibrated
        ? 'Frases com os sons que você mais erra em $languageName.'
        : 'Frases variadas em $languageName, sem foco específico.';

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: false,
      floatingActionButton: const NotebookFab(),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppPageHeader(title: 'Ditado'),
            if (isSubscriber)
              AppTextTabs<bool>(
                selected: _calibrated,
                onSelected: _loading
                    ? (_) {}
                    : (value) => setState(() => _calibrated = value),
                tabs: const [
                  AppTextTab(value: false, label: 'Prática livre'),
                  AppTextTab(value: true, label: 'Ponto fraco'),
                ],
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  96,
                ),
                children: [
                  Row(
                    children: [
                      AppFilterMenu<String>(
                        label: 'Idioma',
                        selected: _language,
                        onSelected: _loading
                            ? (_) {}
                            : (value) => setState(() => _language = value),
                        options: [
                          for (final entry in _languageOptions)
                            AppChoiceOption(
                              value: entry.key,
                              label: entry.value,
                            ),
                        ],
                      ),
                      const Spacer(),
                      AppFilterMenu<int>(
                        label: 'Frases',
                        selected: _sessionSize,
                        onSelected: _loading
                            ? (_) {}
                            : (value) => setState(() => _sessionSize = value),
                        options: [
                          for (final size in _sessionSizeOptions)
                            AppChoiceOption(
                              value: size,
                              label: '$size frases',
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppSurface(
                    borderRadius: _cardRadius,
                    padding: _cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ouça e escreva o que ouviu.',
                          style: textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(modeCopy, style: textTheme.bodyMedium),
                        if (_focusHeadline != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(_focusHeadline!, style: textTheme.bodyMedium),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _error!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.destructive,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _start,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Começar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Últimas sessões',
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_recent.isEmpty)
                    AppSurface(
                      borderRadius: _cardRadius,
                      padding: _cardPadding,
                      child: Text(
                        'Ainda não há sessões. A primeira aparece aqui.',
                        style: textTheme.bodyMedium,
                      ),
                    )
                  else
                    for (final session in _recent) ...[
                      _RecentSessionCard(session: session),
                      const SizedBox(height: AppSpacing.md),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSessionCard extends StatelessWidget {
  const _RecentSessionCard({required this.session});

  final DictationRecentSession session;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppSurface(
      borderRadius: _cardRadius,
      padding: _cardPadding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.dateLabel, style: textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  taughtLanguages[session.language] ?? session.language,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${session.correct}/${session.total}',
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.heading,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
