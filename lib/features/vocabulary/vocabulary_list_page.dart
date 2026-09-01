import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notebook/models/notebook_entry.dart';
import '../notebook/notebook_controller.dart';
import '../notebook/notebook_fab.dart';
import 'flashcard_practice_page.dart';
import 'models/base_vocabulary_entry.dart';
import 'models/srs_schedule.dart';
import 'models/vocab_category.dart';
import 'models/vocab_explain_result.dart';
import 'models/vocabulary_entry.dart';
import 'vocabulary_controller.dart';
import 'vocabulary_repository.dart';
import 'vocab_tts_button.dart';

enum _VocabSection { mine, base, archived }

class VocabularyListPage extends ConsumerStatefulWidget {
  const VocabularyListPage({super.key});

  @override
  ConsumerState<VocabularyListPage> createState() => _VocabularyListPageState();
}

class _VocabularyListPageState extends ConsumerState<VocabularyListPage> {
  _VocabSection _section = _VocabSection.mine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const NotebookFab(),
      appBar: AppBar(
        title: const Text('Vocabulário'),
        actions: [
          if (_section == _VocabSection.mine)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Adicionar palavra',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _AddWordSheet(),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_VocabSection>(
              segments: const [
                ButtonSegment(
                  value: _VocabSection.mine,
                  label: Text('Minhas'),
                  icon: Icon(Icons.style_outlined),
                ),
                ButtonSegment(
                  value: _VocabSection.base,
                  label: Text('Base'),
                  icon: Icon(Icons.menu_book_outlined),
                ),
                ButtonSegment(
                  value: _VocabSection.archived,
                  label: Text('Arquivadas'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (value) =>
                  setState(() => _section = value.first),
            ),
          ),
          Expanded(
            child: switch (_section) {
              _VocabSection.mine => const _MineSection(),
              _VocabSection.base => const _BaseSection(),
              _VocabSection.archived => const _ArchivedSection(),
            },
          ),
        ],
      ),
    );
  }
}

class _MineSection extends ConsumerWidget {
  const _MineSection();

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
      data: (entries) => _MineListBody(entries: entries),
    );
  }
}

class _MineListBody extends ConsumerStatefulWidget {
  const _MineListBody({required this.entries});

  final List<VocabularyEntry> entries;

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
    final categoryNameById = {for (final c in categories) c.id: c.name};
    final categoryFiltered = _categoryFilter == null
        ? widget.entries
        : widget.entries
              .where((e) => e.categoryIds.contains(_categoryFilter))
              .toList();
    final filtered = _kindFilter == null
        ? categoryFiltered
        : categoryFiltered.where((e) => e.entryKind == _kindFilter).toList();

    if (widget.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.style_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Você ainda não tem palavras. Toque em "+" para adicionar a primeira.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final dueCount = widget.entries.where((e) => e.isDue).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dueCount > 0
                      ? '$dueCount palavra(s) pra revisar hoje'
                      : 'Tudo revisado — praticar de novo?',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.style),
                label: const Text('Praticar'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FlashcardPracticePage(kindFilter: _kindFilter),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<VocabEntryKind?>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: null, label: Text('Todas')),
              ButtonSegment(
                value: VocabEntryKind.word,
                label: Text('Palavras'),
              ),
              ButtonSegment(
                value: VocabEntryKind.sentence,
                label: Text('Frases'),
              ),
            ],
            selected: {_kindFilter},
            onSelectionChanged: (value) =>
                setState(() => _kindFilter = value.first),
          ),
        ),
        if (categories.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Todas'),
                    selected: _categoryFilter == null,
                    onSelected: (_) => setState(() => _categoryFilter = null),
                  ),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category.name),
                      selected: _categoryFilter == category.id,
                      onSelected: (selected) => setState(
                        () => _categoryFilter = selected ? category.id : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _kindFilter == VocabEntryKind.sentence
                        ? 'Nenhuma frase nessa seleção.'
                        : 'Nenhuma palavra nessa seleção.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final entryCategoryNames = entry.categoryIds
                        .map((id) => categoryNameById[id])
                        .whereType<String>()
                        .toList();
                    return ListTile(
                      title: Row(
                        children: [
                          Flexible(child: Text(entry.term)),
                          if (entry.entryKind == VocabEntryKind.sentence) ...[
                            const SizedBox(width: 6),
                            const Chip(
                              label: Text('Frase'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                          if (entry.partOfSpeech != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${entry.partOfSpeech})',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${entry.translation} · ${taughtLanguages[entry.language] ?? entry.language} · '
                        '${entry.isDue ? "pronta pra revisar" : formatSrsIntervalLabel(entry.intervalMinutes)}'
                        '${entryCategoryNames.isNotEmpty ? " · ${entryCategoryNames.join(', ')}" : ""}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VocabTtsButton(
                            text: entry.term,
                            language: entry.language,
                          ),
                          IconButton(
                            icon: const Icon(Icons.auto_awesome_outlined),
                            tooltip: 'Explicar com IA',
                            onPressed: () =>
                                _openExplainSheet(context, ref, entry),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Tirar da lista',
                            onPressed: () => ref
                                .read(vocabularyControllerProvider.notifier)
                                .archive(entry.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nenhuma palavra arquivada. Quando você tira uma da lista, ela aparece aqui pra recuperar.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return ListTile(
              title: Text(entry.term),
              subtitle: Text(
                '${entry.translation} · ${taughtLanguages[entry.language] ?? entry.language}',
              ),
              trailing: TextButton(
                onPressed: () => ref
                    .read(archivedVocabularyControllerProvider.notifier)
                    .restore(entry.id),
                child: const Text('Restaurar'),
              ),
            );
          },
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
    final categoryNameById = {for (final c in categories) c.id: c.name};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DropdownButtonFormField<String>(
            key: ValueKey(_language),
            initialValue: _language,
            decoration: const InputDecoration(
              labelText: 'Idioma',
              isDense: true,
            ),
            items: [
              for (final entry in taughtLanguages.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _language = value;
                _categoryFilter = null;
              });
            },
          ),
        ),
        if (categories.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Todas'),
                    selected: _categoryFilter == null,
                    onSelected: (_) => setState(() => _categoryFilter = null),
                  ),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category.name),
                      selected: _categoryFilter == category.id,
                      onSelected: (selected) => setState(
                        () => _categoryFilter = selected ? category.id : null,
                      ),
                    ),
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
                return const Center(
                  child: Text('Nenhuma palavra base nesse filtro.'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final alreadyInMine =
                      savedBaseIds.contains(entry.id) ||
                      mineTerms.contains(entry.term.trim().toLowerCase());
                  final names = entry.categoryIds
                      .map((id) => categoryNameById[id])
                      .whereType<String>()
                      .toList();
                  return ListTile(
                    title: Text(entry.term),
                    subtitle: Text(
                      [
                        entry.translation,
                        if (entry.cefr.isNotEmpty) entry.cefr,
                        if (names.isNotEmpty) names.join(', '),
                      ].join(' · '),
                    ),
                    trailing: alreadyInMine
                        ? const Text('Na lista')
                        : IconButton(
                            icon: _addingId == entry.id
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            tooltip: 'Adicionar às minhas',
                            onPressed: _addingId != null
                                ? null
                                : () => _add(entry),
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
                      : const Icon(Icons.edit_note),
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
              Text(
                _entryKind == VocabEntryKind.sentence
                    ? 'Nova frase'
                    : 'Nova palavra',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SegmentedButton<VocabEntryKind>(
                segments: const [
                  ButtonSegment(
                    value: VocabEntryKind.word,
                    label: Text('Palavra'),
                  ),
                  ButtonSegment(
                    value: VocabEntryKind.sentence,
                    label: Text('Frase'),
                  ),
                ],
                selected: {_entryKind},
                onSelectionChanged: (value) =>
                    setState(() => _entryKind = value.first),
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
                    : const Icon(Icons.auto_awesome, size: 18),
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
                        label: Text(category.name),
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
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
