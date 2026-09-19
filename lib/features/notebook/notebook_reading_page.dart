import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../../design_system/theme/app_typography.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'models/notebook_entry.dart';
import 'notebook_controller.dart';

const _readingStyle = TextStyle(
  fontFamily: AppTypography.titleFontFamily,
  fontSize: 18,
  height: 1.55,
  fontWeight: FontWeight.w400,
  color: AppColors.heading,
);

class NotebookReadingPage extends ConsumerStatefulWidget {
  const NotebookReadingPage({super.key, required this.entry});

  final NotebookEntry entry;

  @override
  ConsumerState<NotebookReadingPage> createState() =>
      _NotebookReadingPageState();
}

class _NotebookReadingPageState extends ConsumerState<NotebookReadingPage> {
  late final TextEditingController _contentController;
  late String _language;
  var _editing = false;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.entry.content,
    );
    _language = widget.entry.language ?? 'EN';
    if (widget.entry.isUnreviewedAi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref
              .read(notebookControllerProvider.notifier)
              .markReviewed(widget.entry.id, reviewed: true),
        );
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  NotebookEntry _liveEntry() {
    final entries = ref.read(notebookControllerProvider).value;
    if (entries != null) {
      for (final entry in entries) {
        if (entry.id == widget.entry.id) return entry;
      }
    }
    return widget.entry;
  }

  String _titleFor(NotebookEntry entry) {
    final title = entry.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final content = entry.content.trim();
    if (content.isEmpty) {
      return entry.entryKind == NotebookEntryKind.aiExplanation
          ? 'Nota da LIA'
          : 'Nota';
    }
    final firstLine = content.split('\n').first.trim();
    return firstLine.length > 80
        ? '${firstLine.substring(0, 80)}…'
        : firstLine;
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _error = 'Escreva alguma coisa.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final current = _liveEntry();
      await ref
          .read(notebookControllerProvider.notifier)
          .updateEntry(
            entryId: current.id,
            content: content,
            language: _language,
            linkType: current.linkType,
            linkId: current.linkId,
            linkLabel: current.linkLabel,
          );
      if (!mounted) return;
      setState(() => _editing = false);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startEditing(NotebookEntry entry) {
    _contentController.text = entry.content;
    _language = entry.language ?? _language;
    setState(() {
      _editing = true;
      _error = null;
    });
  }

  void _cancelEditing(NotebookEntry entry) {
    _contentController.text = entry.content;
    _language = entry.language ?? _language;
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(notebookControllerProvider).value;
    NotebookEntry entry = widget.entry;
    if (entries != null) {
      for (final item in entries) {
        if (item.id == widget.entry.id) {
          entry = item;
          break;
        }
      }
    }
    final languageName = entry.language == null
        ? null
        : (taughtLanguages[entry.language] ?? entry.language);

    return Scaffold(
      backgroundColor: AppColors.backgroundMuted,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CircleButton(
                    icon: LucideIcons.arrow_left,
                    tooltip: 'Voltar',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _titleFor(entry),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  if (entry.entryKind != NotebookEntryKind.aiExplanation) ...[
                    const SizedBox(width: AppSpacing.sm),
                    if (_editing) ...[
                      _CircleButton(
                        icon: LucideIcons.x,
                        tooltip: 'Cancelar',
                        onPressed: _saving
                            ? null
                            : () => _cancelEditing(entry),
                      ),
                      const SizedBox(width: 8),
                      _CircleButton(
                        icon: LucideIcons.check,
                        tooltip: 'Salvar',
                        filled: true,
                        onPressed: _saving ? null : _save,
                      ),
                    ] else
                      _CircleButton(
                        icon: LucideIcons.pencil,
                        tooltip: 'Editar',
                        onPressed: () => _startEditing(entry),
                      ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _Chip(
                          label:
                              entry.entryKind ==
                                  NotebookEntryKind.aiExplanation
                              ? 'LIA'
                              : 'Nota',
                        ),
                        if (_editing)
                          _LanguageChip(
                            selected: _language,
                            onSelected: (value) =>
                                setState(() => _language = value),
                          )
                        else if (languageName != null)
                          _Chip(label: languageName),
                        if (entry.linkLabel != null &&
                            entry.linkLabel!.trim().isNotEmpty)
                          _Chip(label: entry.linkLabel!.trim()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.destructive,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_editing)
                      TextField(
                        controller: _contentController,
                        autofocus: true,
                        minLines: 8,
                        maxLines: null,
                        style: _readingStyle,
                        cursorColor: AppColors.heading,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    else
                      SelectionArea(
                        child: Text(
                          entry.content.trim(),
                          style: _readingStyle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? AppColors.primary : AppColors.background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: filled ? null : Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              size: 20,
              color: filled ? Colors.white : AppColors.heading,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Idioma',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final entry in taughtLanguages.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: _Chip(label: taughtLanguages[selected] ?? selected),
    );
  }
}
