import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vocabulary/models/vocabulary_entry.dart';
import '../vocabulary/vocabulary_controller.dart';
import 'models/notebook_entry.dart';
import 'notebook_controller.dart';

class NotebookListPage extends ConsumerWidget {
  const NotebookListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(notebookControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caderno'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova nota',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _NotebookEntrySheet(),
            ),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Não foi possível carregar o caderno.\n$error', textAlign: TextAlign.center),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Seu caderno está vazio. Toque em "+" para escrever a primeira nota.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                child: ListTile(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _NotebookEntrySheet(entry: entry),
                  ),
                  title: Text(
                    entry.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (entry.language != null)
                          Chip(
                            label: Text(taughtLanguages[entry.language] ?? entry.language!),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (entry.entryKind == NotebookEntryKind.aiExplanation)
                          const Chip(
                            label: Text('IA'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (entry.linkLabel != null)
                          Chip(
                            avatar: const Icon(Icons.link, size: 16),
                            label: Text(entry.linkLabel!),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Apagar',
                    onPressed: () => ref.read(notebookControllerProvider.notifier).deleteEntry(entry.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotebookEntrySheet extends ConsumerStatefulWidget {
  const _NotebookEntrySheet({this.entry});

  final NotebookEntry? entry;

  @override
  ConsumerState<_NotebookEntrySheet> createState() => _NotebookEntrySheetState();
}

class _NotebookEntrySheetState extends ConsumerState<_NotebookEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contentController;
  late String _language;
  VocabularyEntry? _linkedVocabulary;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.entry?.content ?? '');
    _language = widget.entry?.language ?? 'EN';
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final notifier = ref.read(notebookControllerProvider.notifier);
      if (widget.entry == null) {
        await notifier.addEntry(
          content: _contentController.text,
          language: _language,
          linkType: _linkedVocabulary != null ? NotebookLinkType.vocabulary : null,
          linkId: _linkedVocabulary?.id,
          linkLabel: _linkedVocabulary?.term,
        );
      } else {
        await notifier.updateEntry(
          entryId: widget.entry!.id,
          content: _contentController.text,
          language: _language,
          linkType: _linkedVocabulary != null
              ? NotebookLinkType.vocabulary
              : widget.entry!.linkType,
          linkId: _linkedVocabulary?.id ?? widget.entry!.linkId,
          linkLabel: _linkedVocabulary?.term ?? widget.entry!.linkLabel,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocabularyOptions = ref.watch(vocabularyControllerProvider).value ?? const <VocabularyEntry>[];
    final isEditing = widget.entry != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEditing ? 'Editar nota' : 'Nova nota', style: Theme.of(context).textTheme.titleLarge),
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
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Nota'),
                minLines: 3,
                maxLines: 8,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Escreva alguma coisa.' : null,
              ),
              if (vocabularyOptions.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<VocabularyEntry?>(
                  initialValue: _linkedVocabulary,
                  decoration: const InputDecoration(labelText: 'Vincular a uma palavra (opcional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nenhuma')),
                    for (final vocab in vocabularyOptions)
                      DropdownMenuItem(value: vocab, child: Text(vocab.term)),
                  ],
                  onChanged: (value) => setState(() => _linkedVocabulary = value),
                ),
              ],
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
      ),
    );
  }
}
