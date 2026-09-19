import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/navigation/app_text_tabs.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../../design_system/theme/app_typography.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'models/notebook_entry.dart';
import 'notebook_controller.dart';
import 'notebook_entry_sheet.dart';
import 'notebook_reading_page.dart';

const _cardRadius = BorderRadius.all(Radius.circular(16));

class NotebookListPage extends ConsumerStatefulWidget {
  const NotebookListPage({super.key, this.showAiOnly = false});

  final bool showAiOnly;

  @override
  ConsumerState<NotebookListPage> createState() => _NotebookListPageState();
}

class _NotebookListPageState extends ConsumerState<NotebookListPage> {
  late bool _aiOnly = widget.showAiOnly;

  void _openEntry(NotebookEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotebookReadingPage(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(notebookControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundMuted,
      appBar: AppBar(
        title: const Text('Caderno'),
        backgroundColor: AppColors.backgroundMuted,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _AddNoteButton(
              onPressed: () => showNotebookComposer(context),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextTabs<bool>(
            selected: _aiOnly,
            onSelected: (value) => setState(() => _aiOnly = value),
            tabs: const [
              AppTextTab(value: false, label: 'Todas'),
              AppTextTab(value: true, label: 'Notas de IA'),
            ],
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const _EmptyState(
                message: 'Não foi possível carregar o caderno.',
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
                  return _EmptyState(
                    message: _aiOnly
                        ? 'Nenhuma nota de IA ainda. Explique uma palavra no Vocabulário pra gerar a primeira.'
                        : 'Seu caderno está vazio. Escreva a primeira nota.',
                    actionLabel: _aiOnly ? null : 'Nova nota',
                    onAction: _aiOnly
                        ? null
                        : () => showNotebookComposer(context),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.xxxl,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final entry = visible[index];
                    return _NoteCard(
                      entry: entry,
                      onOpen: () => _openEntry(entry),
                      onDelete: () => ref
                          .read(notebookControllerProvider.notifier)
                          .deleteEntry(entry.id),
                      onToggleReviewed: entry.entryKind ==
                              NotebookEntryKind.aiExplanation
                          ? () => ref
                                .read(notebookControllerProvider.notifier)
                                .markReviewed(
                                  entry.id,
                                  reviewed: entry.reviewedAt == null,
                                )
                          : null,
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

class _AddNoteButton extends StatelessWidget {
  const _AddNoteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Nova nota',
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(LucideIcons.plus, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
    this.onToggleReviewed,
  });

  final NotebookEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback? onToggleReviewed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasTitle = entry.title?.trim().isNotEmpty == true;
    final heading = hasTitle ? entry.title!.trim() : entry.content.trim();
    final preview = hasTitle ? entry.content.trim() : '';
    final meta = [
      if (entry.language != null)
        taughtLanguages[entry.language] ?? entry.language!,
      if (entry.linkLabel != null) entry.linkLabel!,
      _dateLabel(entry.updatedAt),
    ].join(' · ');

    return Material(
      color: AppColors.background,
      borderRadius: _cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.entryKind == NotebookEntryKind.aiExplanation) ...[
                      Text(
                        entry.isUnreviewedAi ? 'LIA · nova' : 'LIA',
                        style: AppTypography.microLabel.copyWith(
                          color: AppColors.heading,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Text(
                      heading,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall,
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ],
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(meta, style: textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: PopupMenuButton<_NoteMenu>(
              tooltip: 'Mais',
              padding: EdgeInsets.zero,
              icon: const Icon(
                LucideIcons.ellipsis,
                size: 18,
                color: AppColors.navText,
              ),
              onSelected: (value) {
                switch (value) {
                  case _NoteMenu.toggleReviewed:
                    onToggleReviewed?.call();
                  case _NoteMenu.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                if (onToggleReviewed != null)
                  PopupMenuItem(
                    value: _NoteMenu.toggleReviewed,
                    child: Text(
                      entry.reviewedAt == null
                          ? 'Marcar como vista'
                          : 'Marcar como não vista',
                    ),
                  ),
                const PopupMenuItem(
                  value: _NoteMenu.delete,
                  child: Text('Apagar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

enum _NoteMenu { toggleReviewed, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.notebook,
              size: 36,
              color: AppColors.heading,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.heading,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
