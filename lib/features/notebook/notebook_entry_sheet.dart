import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_radius.dart';
import '../../design_system/theme/app_spacing.dart';
import '../library/library_controller.dart';
import '../library/models/library_text.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import '../vocabulary/vocabulary_controller.dart';
import 'models/notebook_entry.dart';
import 'notebook_controller.dart';

class NotebookEntrySheet extends ConsumerStatefulWidget {
  const NotebookEntrySheet({super.key});

  @override
  ConsumerState<NotebookEntrySheet> createState() => _NotebookEntrySheetState();
}

class _NotebookEntrySheetState extends ConsumerState<NotebookEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contentController;
  late String _language;
  VocabularyEntry? _linkedVocabulary;
  LibraryText? _linkedText;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _language = 'EN';
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
      NotebookLinkType? linkType;
      String? linkId;
      String? linkLabel;
      if (_linkedVocabulary != null) {
        linkType = NotebookLinkType.vocabulary;
        linkId = _linkedVocabulary!.id;
        linkLabel = _linkedVocabulary!.term;
      } else if (_linkedText != null) {
        linkType = NotebookLinkType.libraryText;
        linkId = _linkedText!.id;
        linkLabel = _linkedText!.title;
      }

      await notifier.addEntry(
        content: _contentController.text,
        language: _language,
        linkType: linkType,
        linkId: linkId,
        linkLabel: linkLabel,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocabularyOptions =
        ref.watch(vocabularyControllerProvider).value ??
        const <VocabularyEntry>[];
    final textOptions =
        ref.watch(libraryControllerProvider).value?.texts ??
        const <LibraryText>[];
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nova nota',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
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
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Nota'),
                minLines: 3,
                maxLines: 8,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Escreva alguma coisa.'
                    : null,
              ),
              if (vocabularyOptions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<VocabularyEntry?>(
                  initialValue: _linkedVocabulary,
                  decoration: const InputDecoration(
                    labelText: 'Vincular a uma palavra (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nenhuma')),
                    for (final vocab in vocabularyOptions)
                      DropdownMenuItem(value: vocab, child: Text(vocab.term)),
                  ],
                  onChanged: (value) => setState(() {
                    _linkedVocabulary = value;
                    if (value != null) _linkedText = null;
                  }),
                ),
              ],
              if (textOptions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<LibraryText?>(
                  initialValue: _linkedText,
                  decoration: const InputDecoration(
                    labelText: 'Vincular a um texto da biblioteca (opcional)',
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nenhum')),
                    for (final text in textOptions)
                      DropdownMenuItem(
                        value: text,
                        child: Text(
                          text.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _linkedText = value;
                    if (value != null) _linkedVocabulary = null;
                  }),
                ),
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
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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

void showNotebookComposer(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => const NotebookEntrySheet(),
  );
}
