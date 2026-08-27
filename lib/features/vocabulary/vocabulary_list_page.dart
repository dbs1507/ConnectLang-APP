import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flashcard_practice_page.dart';
import 'models/srs_schedule.dart';
import 'models/vocabulary_entry.dart';
import 'vocabulary_controller.dart';
import 'vocabulary_repository.dart';

class VocabularyListPage extends ConsumerWidget {
  const VocabularyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(vocabularyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulário'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Adicionar palavra',
            onPressed: () => _openAddWordSheet(context, ref),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Não foi possível carregar seu vocabulário.\n$error', textAlign: TextAlign.center),
          ),
        ),
        data: (entries) => _VocabularyListBody(entries: entries),
      ),
    );
  }

  void _openAddWordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddWordSheet(),
    );
  }
}

class _VocabularyListBody extends ConsumerWidget {
  const _VocabularyListBody({required this.entries});

  final List<VocabularyEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
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

    final dueCount = entries.where((e) => e.isDue).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dueCount > 0 ? '$dueCount palavra(s) pra revisar hoje' : 'Tudo revisado — praticar de novo?',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.style),
                label: const Text('Praticar'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FlashcardPracticePage()),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Row(
                  children: [
                    Flexible(child: Text(entry.term)),
                    if (entry.partOfSpeech != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${entry.partOfSpeech})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${entry.translation} · ${taughtLanguages[entry.language] ?? entry.language} · '
                  '${entry.isDue ? "pronta pra revisar" : formatSrsIntervalLabel(entry.intervalMinutes)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Tirar da lista',
                  onPressed: () => ref.read(vocabularyControllerProvider.notifier).archive(entry.id),
                ),
              );
            },
          ),
        ),
      ],
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
      final result = await ref.read(vocabularyRepositoryProvider).enrichTerm(term: term, language: _language);
      if (result == null) {
        setState(() => _error = 'Não foi possível preencher com IA. Tente novamente.');
        return;
      }
      setState(() {
        if (result.translation.isNotEmpty) _translationController.text = result.translation;
        if (result.example.isNotEmpty) _contextController.text = result.example;
        _aiDescription = result.description.isNotEmpty ? result.description : null;
        _aiPartOfSpeech = result.partOfSpeech;
      });
    } catch (_) {
      setState(() => _error = 'Não foi possível preencher com IA. Tente novamente.');
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
      await ref.read(vocabularyControllerProvider.notifier).addWord(
            term: _termController.text,
            translation: _translationController.text,
            language: _language,
            context: _contextController.text,
            example: _contextController.text.trim().isNotEmpty ? _contextController.text : null,
            description: _aiDescription,
            partOfSpeech: _aiPartOfSpeech,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nova palavra', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(labelText: 'Idioma'),
              items: [
                for (final entry in taughtLanguages.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _language = value ?? _language),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _termController,
              decoration: const InputDecoration(labelText: 'Palavra'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Informe a palavra.' : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _enriching ? null : _enrichWithAi,
              icon: _enriching
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Preencher com IA'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _translationController,
              decoration: const InputDecoration(labelText: 'Tradução'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Informe a tradução.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contextController,
              decoration: const InputDecoration(labelText: 'Frase de exemplo (opcional)'),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
