import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/cards/app_surface.dart';
import '../../design_system/components/navigation/app_choice_chips.dart';
import '../../design_system/components/navigation/app_filter_menu.dart';
import '../../design_system/components/navigation/app_page_header.dart';
import '../../design_system/components/navigation/app_text_tabs.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../../design_system/theme/app_typography.dart';
import '../notebook/models/notebook_entry.dart';
import '../notebook/notebook_controller.dart';
import '../notebook/notebook_fab.dart';
import 'flashcard_practice_page.dart';
import 'models/base_vocabulary_entry.dart';
import 'models/vocab_category.dart';
import 'models/vocab_explain_result.dart';
import 'models/vocabulary_entry.dart';
import 'vocabulary_controller.dart';
import 'vocabulary_repository.dart';
import 'vocab_tts_button.dart';

enum _VocabSection { mine, base, archived }

const _vocabCardRadius = BorderRadius.all(Radius.circular(16));
const _vocabCardPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  AppSpacing.lg,
  AppSpacing.xl,
  AppSpacing.lg,
);
const _smallListThreshold = 8;

class VocabularyListPage extends ConsumerStatefulWidget {
  const VocabularyListPage({super.key});

  @override
  ConsumerState<VocabularyListPage> createState() => _VocabularyListPageState();
}

class _VocabularyListPageState extends ConsumerState<VocabularyListPage> {
  _VocabSection _section = _VocabSection.mine;
  bool _addWordSheetOpen = false;

  Future<void> _openAddWordSheet() async {
    setState(() => _addWordSheetOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => const _AddWordSheet(),
      );
    } finally {
      if (mounted) setState(() => _addWordSheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: false,
      floatingActionButton: _addWordSheetOpen ? null : const NotebookFab(),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: 'Vocabulário',
              trailing: _AddWordButton(onPressed: _openAddWordSheet),
            ),
            AppTextTabs<_VocabSection>(
              selected: _section,
              onSelected: (value) => setState(() => _section = value),
              tabs: const [
                AppTextTab(value: _VocabSection.mine, label: 'Minhas'),
                AppTextTab(value: _VocabSection.base, label: 'Padrão'),
                AppTextTab(
                  value: _VocabSection.archived,
                  label: 'Arquivadas',
                ),
              ],
            ),
            Expanded(
              child: switch (_section) {
                _VocabSection.mine => _MineSection(
                  onExploreBase: () =>
                      setState(() => _section = _VocabSection.base),
                ),
                _VocabSection.base => const _BaseSection(),
                _VocabSection.archived => const _ArchivedSection(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWordButton extends StatelessWidget {
  const _AddWordButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Adicionar palavra',
      child: Material(
        color: AppColors.background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              LucideIcons.plus,
              size: 20,
              color: AppColors.heading,
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.dueCount,
    required this.onPractice,
  });

  final int dueCount;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.heading,
      borderRadius: _vocabCardRadius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dueCount > 0 ? 'Pra revisar' : 'Em dia',
              style: AppTypography.microLabel.copyWith(
                color: AppColors.primarySoft,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              dueCount > 0
                  ? '$dueCount palavra${dueCount == 1 ? '' : 's'} pra hoje'
                  : 'Tudo revisado — praticar de novo?',
              style: textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              dueCount > 0
                  ? 'Passaram da hora. Uma revisão rápida agora segura o que você já aprendeu.'
                  : 'Nada pendente hoje. Se quiser, dá pra reforçar o que já está no caderno.',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onPractice,
              child: const Text('Praticar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabTermRow extends StatelessWidget {
  const _VocabTermRow({
    required this.term,
    required this.subtitle,
    required this.trailing,
    this.due = false,
  });

  final String term;
  final String subtitle;
  final Widget trailing;
  final bool due;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(term, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (due) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.terracotta,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconTheme(
            data: const IconThemeData(color: AppColors.foreground, size: 20),
            child: trailing,
          ),
        ],
      ),
    );
  }
}

class _LibrarySuggestionCard extends StatelessWidget {
  const _LibrarySuggestionCard({
    required this.body,
    required this.onExplore,
  });

  final String body;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      borderRadius: _vocabCardRadius,
      padding: _vocabCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Biblioteca padrão', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onExplore,
              child: const Text('Explorar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MineSection extends ConsumerWidget {
  const _MineSection({required this.onExploreBase});

  final VoidCallback onExploreBase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(vocabularyControllerProvider);
    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Não foi possível carregar seu vocabulário.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (entries) =>
          _MineListBody(entries: entries, onExploreBase: onExploreBase),
    );
  }
}

class _MineListBody extends ConsumerStatefulWidget {
  const _MineListBody({required this.entries, required this.onExploreBase});

  final List<VocabularyEntry> entries;
  final VoidCallback onExploreBase;

  @override
  ConsumerState<_MineListBody> createState() => _MineListBodyState();
}

class _MineListBodyState extends ConsumerState<_MineListBody> {
  String? _categoryFilter;
  VocabEntryKind? _kindFilter;

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(vocabularyCategoriesProvider).value ??
        const <VocabCategory>[];
    final categoryFiltered = _categoryFilter == null
        ? widget.entries
        : widget.entries
              .where((e) => e.categoryIds.contains(_categoryFilter))
              .toList();
    final filtered = _kindFilter == null
        ? categoryFiltered
        : categoryFiltered.where((e) => e.entryKind == _kindFilter).toList();

    if (widget.entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        children: [
          AppSurface(
            borderRadius: _vocabCardRadius,
            padding: _vocabCardPadding,
            child: Text(
              'Você ainda não tem palavras. Toque em + para adicionar a primeira.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _LibrarySuggestionCard(
            body: _librarySuggestionBody(categories),
            onExplore: widget.onExploreBase,
          ),
        ],
      );
    }

    final dueCount = widget.entries.where((e) => e.isDue).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      children: [
        _PracticeCard(
          dueCount: dueCount,
          onPractice: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FlashcardPracticePage(kindFilter: _kindFilter),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            AppFilterMenu<VocabEntryKind?>(
              label: 'Tipo',
              selected: _kindFilter,
              onSelected: (value) => setState(() => _kindFilter = value),
              options: const [
                AppChoiceOption(value: null, label: 'Todas'),
                AppChoiceOption(value: VocabEntryKind.word, label: 'Palavras'),
                AppChoiceOption(
                  value: VocabEntryKind.sentence,
                  label: 'Frases',
                ),
              ],
            ),
            const Spacer(),
            if (categories.isNotEmpty)
              AppFilterMenu<String?>(
                label: 'Categoria',
                selected: _categoryFilter,
                onSelected: (value) => setState(() => _categoryFilter = value),
                options: [
                  const AppChoiceOption(value: null, label: 'Todas'),
                  for (final category in categories)
                    AppChoiceOption(value: category.id, label: category.name),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (filtered.isEmpty)
          AppSurface(
            borderRadius: _vocabCardRadius,
            padding: _vocabCardPadding,
            child: Text(
              _kindFilter == VocabEntryKind.sentence
                  ? 'Nenhuma frase nessa seleção.'
                  : 'Nenhuma palavra nessa seleção.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          for (final entry in filtered) ...[
            AppSurface(
              borderRadius: _vocabCardRadius,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: _mineWordRow(entry),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        if (widget.entries.length < _smallListThreshold) ...[
          const SizedBox(height: AppSpacing.lg),
          _LibrarySuggestionCard(
            body: _librarySuggestionBody(categories),
            onExplore: widget.onExploreBase,
          ),
        ],
      ],
    );
  }

  Widget _mineWordRow(VocabularyEntry entry) {
    return _VocabTermRow(
      term: entry.term,
      due: entry.isDue,
      subtitle:
          '${entry.translation} · ${taughtLanguages[entry.language] ?? entry.language}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VocabTtsButton(text: entry.term, language: entry.language),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.ellipsis),
            onSelected: (value) {
              if (value == 'explain') {
                _openExplainSheet(context, ref, entry);
              } else if (value == 'archive') {
                ref.read(vocabularyControllerProvider.notifier).archive(entry.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'explain',
                child: Text('Explicar com IA'),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text('Tirar da lista'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _librarySuggestionBody(List<VocabCategory> categories) {
  const preferred = ['Viagem', 'Trabalho'];
  final available = [
    for (final category in categories)
      if (category.name.trim().isNotEmpty) category.name.trim(),
  ];
  final names = <String>[
    for (final name in preferred)
      if (available.any((item) => item.toLowerCase() == name.toLowerCase()))
        available.firstWhere((item) => item.toLowerCase() == name.toLowerCase()),
  ];
  for (final name in available) {
    if (names.length >= 2) break;
    if (!names.contains(name)) names.add(name);
  }
  if (names.length >= 2) {
    return 'Sua lista está pequena. Que tal adicionar palavras de "${names[0]}" ou "${names[1]}" pra praticar mais?';
  }
  if (names.length == 1) {
    return 'Sua lista está pequena. Que tal adicionar palavras de "${names[0]}" pra praticar mais?';
  }
  return 'Sua lista está pequena. Que tal adicionar palavras da biblioteca padrão pra praticar mais?';
}

class _ArchivedSection extends ConsumerWidget {
  const _ArchivedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedVocabularyControllerProvider);
    return archivedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Não foi possível carregar as arquivadas.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            children: [
              AppSurface(
                borderRadius: _vocabCardRadius,
                padding: _vocabCardPadding,
                child: Text(
                  'Nenhuma palavra arquivada. Quando você tira uma da lista, ela aparece aqui pra recuperar.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            for (final entry in entries) ...[
              AppSurface(
                borderRadius: _vocabCardRadius,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: _VocabTermRow(
                  term: entry.term,
                  subtitle:
                      '${entry.translation} · ${taughtLanguages[entry.language] ?? entry.language}',
                  trailing: TextButton(
                    onPressed: () => ref
                        .read(archivedVocabularyControllerProvider.notifier)
                        .restore(entry.id),
                    child: const Text('Restaurar'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _BaseSection extends ConsumerStatefulWidget {
  const _BaseSection();

  @override
  ConsumerState<_BaseSection> createState() => _BaseSectionState();
}

class _BaseSectionState extends ConsumerState<_BaseSection> {
  String _language = 'EN';
  String? _categoryFilter;
  String? _addingId;

  @override
  Widget build(BuildContext context) {
    final baseAsync = ref.watch(baseVocabularyProvider(_language));
    final mine =
        ref.watch(vocabularyControllerProvider).value ??
        const <VocabularyEntry>[];
    final savedBaseIds = {
      for (final e in mine)
        if (e.savedFromBaseVocabId != null) e.savedFromBaseVocabId!,
    };
    final mineTerms = {
      for (final e in mine.where((e) => e.language == _language))
        e.term.trim().toLowerCase(),
    };
    final categories =
        ref.watch(vocabularyCategoriesProvider).value ??
        const <VocabCategory>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Row(
            children: [
              AppFilterMenu<String>(
                label: 'Idioma',
                selected: _language,
                onSelected: (value) => setState(() {
                  _language = value;
                  _categoryFilter = null;
                }),
                options: [
                  for (final entry in taughtLanguages.entries)
                    AppChoiceOption(value: entry.key, label: entry.value),
                ],
              ),
              const Spacer(),
              if (categories.isNotEmpty)
                AppFilterMenu<String?>(
                  label: 'Categoria',
                  selected: _categoryFilter,
                  onSelected: (value) =>
                      setState(() => _categoryFilter = value),
                  options: [
                    const AppChoiceOption(value: null, label: 'Todas'),
                    for (final category in categories)
                      AppChoiceOption(
                        value: category.id,
                        label: category.name,
                      ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: baseAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar o vocabulário base.\n$error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (entries) {
              final filtered = _categoryFilter == null
                  ? entries
                  : entries
                        .where((e) => e.categoryIds.contains(_categoryFilter))
                        .toList();
              if (filtered.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxxl,
                  ),
                  children: [
                    AppSurface(
                      borderRadius: _vocabCardRadius,
                      padding: _vocabCardPadding,
                      child: Text(
                        'Nenhuma palavra base nesse filtro.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xxxl,
                ),
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final alreadyInMine =
                      savedBaseIds.contains(entry.id) ||
                      mineTerms.contains(entry.term.trim().toLowerCase());
                  return AppSurface(
                    borderRadius: _vocabCardRadius,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: _VocabTermRow(
                      term: entry.term,
                      subtitle: [
                        entry.translation,
                        if (entry.cefr.isNotEmpty) entry.cefr,
                      ].join(' · '),
                      trailing: alreadyInMine
                          ? Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: Text(
                                'Na lista',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            )
                          : IconButton(
                              icon: _addingId == entry.id
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(LucideIcons.plus),
                              tooltip: 'Adicionar às minhas',
                              onPressed: _addingId != null
                                  ? null
                                  : () => _add(entry),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _add(BaseVocabularyEntry entry) async {
    setState(() => _addingId = entry.id);
    try {
      await ref.read(vocabularyControllerProvider.notifier).addFromBase(entry);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${entry.term} adicionada às suas palavras.')),
        );
      }
    } on DuplicateVocabularyTermException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esse termo já está na sua lista.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível adicionar. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }
}

Future<void> _openExplainSheet(
  BuildContext context,
  WidgetRef ref,
  VocabularyEntry entry,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExplainSheet(entry: entry),
  );
}

class _ExplainSheet extends ConsumerStatefulWidget {
  const _ExplainSheet({required this.entry});

  final VocabularyEntry entry;

  @override
  ConsumerState<_ExplainSheet> createState() => _ExplainSheetState();
}

class _ExplainSheetState extends ConsumerState<_ExplainSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  VocabExplainResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(vocabularyRepositoryProvider)
          .explainTerm(
            term: widget.entry.term,
            language: widget.entry.language,
            translation: widget.entry.translation,
            example: widget.entry.example,
            context: widget.entry.context,
            description: widget.entry.description,
          );
      if (!mounted) return;
      setState(() => _result = result);
      if (result == null) {
        setState(
          () => _error = 'Não foi possível explicar essa palavra agora.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível explicar essa palavra agora.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToNotebook() async {
    final result = _result;
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(notebookControllerProvider.notifier)
          .addAiExplanation(
            content: result.notebookContent(),
            language: widget.entry.language,
            title: result.notebookTitle(widget.entry.term),
            aiSource: 'vocab_explain',
            linkType: NotebookLinkType.vocabulary,
            linkId: widget.entry.id,
            linkLabel: widget.entry.term,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Explicação salva no caderno.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar no caderno.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Explicar: ${widget.entry.term}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (result != null) ...[
                Text(result.explanation),
                if (result.whyHard.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Por que é difícil',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(result.whyHard),
                ],
                if (result.examples.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Exemplos',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final example in result.examples) Text('• $example'),
                ],
                if (result.tip.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Dica', style: Theme.of(context).textTheme.titleSmall),
                  Text(result.tip),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveToNotebook,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.notebook_pen),
                  label: const Text('Salvar no caderno'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AddWordSheet extends ConsumerStatefulWidget {
  const _AddWordSheet();

  @override
  ConsumerState<_AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends ConsumerState<_AddWordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _termController = TextEditingController();
  final _translationController = TextEditingController();
  final _contextController = TextEditingController();
  String _language = 'EN';
  bool _submitting = false;
  bool _enriching = false;
  String? _error;
  String? _aiDescription;
  String? _aiPartOfSpeech;
  final Set<String> _selectedCategoryIds = {};
  VocabEntryKind _entryKind = VocabEntryKind.word;

  @override
  void dispose() {
    _termController.dispose();
    _translationController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _enrichWithAi() async {
    final term = _termController.text.trim();
    if (term.isEmpty) {
      setState(() => _error = 'Digite a palavra antes de preencher com IA.');
      return;
    }
    setState(() {
      _enriching = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(vocabularyRepositoryProvider)
          .enrichTerm(term: term, language: _language, entryKind: _entryKind);
      if (result == null) {
        setState(
          () => _error = 'Não foi possível preencher com IA. Tente novamente.',
        );
        return;
      }
      setState(() {
        if (result.translation.isNotEmpty) {
          _translationController.text = result.translation;
        }
        if (result.example.isNotEmpty) _contextController.text = result.example;
        _aiDescription = result.description.isNotEmpty
            ? result.description
            : null;
        _aiPartOfSpeech = result.partOfSpeech;
      });
    } catch (_) {
      setState(
        () => _error = 'Não foi possível preencher com IA. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _enriching = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(vocabularyControllerProvider.notifier)
          .addWord(
            term: _termController.text,
            translation: _translationController.text,
            language: _language,
            context: _contextController.text,
            example: _contextController.text.trim().isNotEmpty
                ? _contextController.text
                : null,
            description: _aiDescription,
            partOfSpeech: _aiPartOfSpeech,
            categoryIds: _selectedCategoryIds.toList(),
            entryKind: _entryKind,
          );
      if (mounted) Navigator.of(context).pop();
    } on DuplicateVocabularyTermException {
      setState(() => _error = 'Esse termo já está na sua lista.');
    } catch (_) {
      setState(() => _error = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(vocabularyCategoriesProvider).value ??
        const <VocabCategory>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _entryKind == VocabEntryKind.sentence
                          ? 'Nova frase'
                          : 'Nova palavra',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    tooltip: 'Fechar',
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextTabs<VocabEntryKind>(
                selected: _entryKind,
                compact: true,
                padding: EdgeInsets.zero,
                onSelected: (value) => setState(() => _entryKind = value),
                tabs: const [
                  AppTextTab(value: VocabEntryKind.word, label: 'Palavra'),
                  AppTextTab(value: VocabEntryKind.sentence, label: 'Frase'),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Idioma'),
                items: [
                  for (final entry in taughtLanguages.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _language = value ?? _language),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _termController,
                decoration: InputDecoration(
                  labelText: _entryKind == VocabEntryKind.sentence
                      ? 'Frase ou expressão'
                      : 'Palavra',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? (_entryKind == VocabEntryKind.sentence
                          ? 'Informe a frase.'
                          : 'Informe a palavra.')
                    : null,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _enriching ? null : _enrichWithAi,
                icon: _enriching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.astroid, size: 18),
                label: const Text('Preencher com IA'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _translationController,
                decoration: const InputDecoration(labelText: 'Tradução'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe a tradução.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contextController,
                decoration: InputDecoration(
                  labelText: _entryKind == VocabEntryKind.sentence
                      ? 'Contexto (opcional)'
                      : 'Frase de exemplo (opcional)',
                ),
                maxLines: 2,
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Categorias (opcional)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in categories)
                      FilterChip(
                        label: Text(
                          category.name,
                          style: TextStyle(
                            color: _selectedCategoryIds.contains(category.id)
                                ? Colors.white
                                : AppColors.foreground,
                          ),
                        ),
                        selected: _selectedCategoryIds.contains(category.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _selectedCategoryIds.add(category.id);
                          } else {
                            _selectedCategoryIds.remove(category.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
