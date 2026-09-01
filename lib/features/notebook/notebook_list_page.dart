import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vocabulary/models/vocabulary_entry.dart';
import 'models/notebook_entry.dart';
import 'notebook_controller.dart';
import 'notebook_entry_sheet.dart';

class NotebookListPage extends ConsumerStatefulWidget {
  const NotebookListPage({super.key, this.showAiOnly = false});

  final bool showAiOnly;

  @override
  ConsumerState<NotebookListPage> createState() => _NotebookListPageState();
}

class _NotebookListPageState extends ConsumerState<NotebookListPage> {
  late bool _aiOnly = widget.showAiOnly;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(notebookControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caderno'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova nota',
            onPressed: () => showNotebookComposer(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Todas')),
                ButtonSegment(value: true, label: Text('Notas de IA')),
              ],
              selected: {_aiOnly},
              onSelectionChanged: (value) =>
                  setState(() => _aiOnly = value.first),
            ),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Não foi possível carregar o caderno.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (entries) {
                final visible = _aiOnly
                    ? entries
                          .where(
                            (e) =>
                                e.entryKind == NotebookEntryKind.aiExplanation,
                          )
                          .toList()
                    : entries;
                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _aiOnly
                                ? 'Nenhuma nota de IA ainda. Explique uma palavra no Vocabulário pra gerar a primeira.'
                                : 'Seu caderno está vazio. Toque em "+" para escrever a primeira nota.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = visible[index];
                    return Card(
                      child: ListTile(
                        onTap: () =>
                            showNotebookComposer(context, entry: entry),
                        title: Text(
                          entry.title?.trim().isNotEmpty == true
                              ? entry.title!
                              : entry.content,
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
                                  label: Text(
                                    taughtLanguages[entry.language] ??
                                        entry.language!,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              if (entry.entryKind ==
                                  NotebookEntryKind.aiExplanation)
                                Chip(
                                  label: Text(
                                    entry.isUnreviewedAi ? 'IA · nova' : 'IA',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              if (entry.linkLabel != null)
                                Chip(
                                  avatar: const Icon(Icons.link, size: 16),
                                  label: Text(entry.linkLabel!),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (entry.entryKind ==
                                NotebookEntryKind.aiExplanation)
                              IconButton(
                                icon: Icon(
                                  entry.reviewedAt == null
                                      ? Icons.mark_email_unread_outlined
                                      : Icons.done_all,
                                ),
                                tooltip: entry.reviewedAt == null
                                    ? 'Marcar como vista'
                                    : 'Marcar como não vista',
                                onPressed: () => ref
                                    .read(notebookControllerProvider.notifier)
                                    .markReviewed(
                                      entry.id,
                                      reviewed: entry.reviewedAt == null,
                                    ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Apagar',
                              onPressed: () => ref
                                  .read(notebookControllerProvider.notifier)
                                  .deleteEntry(entry.id),
                            ),
                          ],
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
}
