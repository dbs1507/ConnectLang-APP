import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notebook/notebook_fab.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'library_controller.dart';
import 'library_repository.dart';
import 'models/library_text.dart';
import 'text_reading_page.dart';

enum _LibrarySection { curated, temporary, personal }

class LibraryListPage extends ConsumerStatefulWidget {
  const LibraryListPage({super.key, this.initialTextId});

  final String? initialTextId;

  @override
  ConsumerState<LibraryListPage> createState() => _LibraryListPageState();
}

class _LibraryListPageState extends ConsumerState<LibraryListPage> {
  _LibrarySection _section = _LibrarySection.curated;
  bool _openedInitial = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTextId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openInitialIfReady(),
      );
    }
  }

  void _openInitialIfReady() {
    if (_openedInitial || widget.initialTextId == null) return;
    final data = ref.read(libraryControllerProvider).value;
    if (data == null) return;
    final id = widget.initialTextId!;
    LibraryText? match;
    for (final text in [
      ...data.texts,
      ...data.temporaryTexts,
      ...data.personalTexts,
    ]) {
      if (text.id == id) {
        match = text;
        break;
      }
    }
    if (match == null) return;
    _openedInitial = true;
    if (match.sourceKind == LibraryTextSource.temporary) {
      _section = _LibrarySection.temporary;
    } else if (match.sourceKind == LibraryTextSource.personal) {
      _section = _LibrarySection.personal;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TextReadingPage(text: match!)));
  }

  List<LibraryText> _textsFor(LibraryState state) {
    return switch (_section) {
      _LibrarySection.curated => state.texts,
      _LibrarySection.temporary => state.temporaryTexts,
      _LibrarySection.personal => state.personalTexts,
    };
  }

  Future<void> _pasteTemporary() async {
    final created = await showModalBottomSheet<LibraryText>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PasteTemporarySheet(),
    );
    if (!mounted || created == null) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TextReadingPage(text: created)));
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(libraryControllerProvider);
    ref.listen(libraryControllerProvider, (_, _) => _openInitialIfReady());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [
          if (_section == _LibrarySection.temporary)
            IconButton(
              icon: const Icon(Icons.content_paste_go_outlined),
              tooltip: 'Colar texto',
              onPressed: _pasteTemporary,
            ),
        ],
      ),
      floatingActionButton: const NotebookFab(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_LibrarySection>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _LibrarySection.curated,
                  label: Text('Curada'),
                ),
                ButtonSegment(
                  value: _LibrarySection.temporary,
                  label: Text('Temp.'),
                ),
                ButtonSegment(
                  value: _LibrarySection.personal,
                  label: Text('Pessoais'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (value) =>
                  setState(() => _section = value.first),
            ),
          ),
          Expanded(
            child: stateAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Não foi possível carregar a biblioteca.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (libraryState) {
                final texts = _textsFor(libraryState);
                if (texts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_emptyMessage, textAlign: TextAlign.center),
                          if (_section == _LibrarySection.temporary) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _pasteTemporary,
                              icon: const Icon(Icons.content_paste_go_outlined),
                              label: const Text('Colar um texto'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: texts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final text = texts[index];
                    final isRead = libraryState.isRead(text.id);
                    return ListTile(
                      title: Text(text.title),
                      subtitle: Text(
                        [
                          taughtLanguages[text.language] ?? text.language,
                          if (text.cefr != null) text.cefr!,
                          if (text.sourceKind == LibraryTextSource.temporary &&
                              text.expiresAt != null)
                            'expira em ${text.formatExpiresIn()}',
                        ].join(' · '),
                      ),
                      trailing: text.isOwned
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Apagar',
                              onPressed: () => ref
                                  .read(libraryControllerProvider.notifier)
                                  .deleteOwned(text),
                            )
                          : IconButton(
                              icon: Icon(
                                isRead
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                              ),
                              tooltip: isRead
                                  ? 'Marcar como não lido'
                                  : 'Marcar como lido',
                              onPressed: () => ref
                                  .read(libraryControllerProvider.notifier)
                                  .toggleRead(text),
                            ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TextReadingPage(text: text),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String get _emptyMessage {
    return switch (_section) {
      _LibrarySection.curated => 'Ainda não há textos na biblioteca.',
      _LibrarySection.temporary =>
        'Nenhum texto temporário. Cole um texto pra ler, ouvir e gerar perguntas — ele some em 48h.',
      _LibrarySection.personal =>
        'Nenhum texto pessoal ainda. Salve um temporário pra guardar.',
    };
  }
}

class _PasteTemporarySheet extends ConsumerStatefulWidget {
  const _PasteTemporarySheet();

  @override
  ConsumerState<_PasteTemporarySheet> createState() =>
      _PasteTemporarySheetState();
}

class _PasteTemporarySheetState extends ConsumerState<_PasteTemporarySheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _language = 'EN';
  String? _cefr;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) {
      setState(() => _error = 'Cole o conteúdo do texto.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(libraryControllerProvider.notifier)
          .createTemporary(
            title: _titleController.text,
            content: _contentController.text,
            language: _language,
            cefr: _cefr,
          );
      if (mounted) Navigator.of(context).pop(created);
    } on OwnedTextException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'daily_limit' =>
            'Limite de $tempTextsPerDay textos temporários por dia.',
          'empty' => 'Cole o conteúdo do texto.',
          _ => 'Não foi possível salvar o texto.',
        };
      });
    } catch (_) {
      setState(() => _error = 'Não foi possível salvar o texto.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Colar texto temporário',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Fica 48h. Dá pra salvar como pessoal depois. Máx. $tempTextsPerDay por dia.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título (opcional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(labelText: 'Idioma'),
              items: [
                for (final entry in taughtLanguages.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) =>
                  setState(() => _language = value ?? _language),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _cefr,
              decoration: const InputDecoration(labelText: 'Nível (opcional)'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Sem nível')),
                DropdownMenuItem(value: 'A1', child: Text('A1')),
                DropdownMenuItem(value: 'A2', child: Text('A2')),
                DropdownMenuItem(value: 'B1', child: Text('B1')),
                DropdownMenuItem(value: 'B2', child: Text('B2')),
                DropdownMenuItem(value: 'C1', child: Text('C1')),
              ],
              onChanged: (value) => setState(() => _cefr = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Texto'),
              minLines: 6,
              maxLines: 12,
            ),
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
                  : const Text('Salvar texto'),
            ),
          ],
        ),
      ),
    );
  }
}
