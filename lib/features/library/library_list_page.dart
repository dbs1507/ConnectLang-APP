import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../vocabulary/vocabulary_controller.dart';
import 'library_controller.dart';
import 'library_repository.dart';
import 'models/library_text.dart';
import 'text_reading_page.dart';

enum _LibrarySection { curated, temporary, personal }

const _libraryCardRadius = BorderRadius.all(Radius.circular(16));
const _libraryBodyPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  AppSpacing.sm,
  AppSpacing.xl,
  AppSpacing.xxxl,
);
const _libraryCardPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  AppSpacing.lg,
  AppSpacing.xl,
  AppSpacing.lg,
);

class LibraryListPage extends ConsumerStatefulWidget {
  const LibraryListPage({super.key, this.initialTextId});

  final String? initialTextId;

  @override
  ConsumerState<LibraryListPage> createState() => _LibraryListPageState();
}

class _LibraryListPageState extends ConsumerState<LibraryListPage> {
  _LibrarySection _section = _LibrarySection.curated;
  String? _openedTextId;
  String? _languageFilter;
  String? _cefrFilter;
  var _didInitLanguage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLanguageFilter();
      final id = widget.initialTextId;
      if (id != null) unawaited(_openTextById(id));
    });
  }

  @override
  void didUpdateWidget(covariant LibraryListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.initialTextId;
    if (id != null && id != oldWidget.initialTextId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openTextById(id));
      });
    }
  }

  void _initLanguageFilter() {
    if (_didInitLanguage) return;
    _didInitLanguage = true;
    final codes =
        ref.read(authControllerProvider).value?.studyLanguages ?? const [];
    if (codes.isEmpty) return;
    setState(() => _languageFilter = codes.first.toUpperCase());
  }

  Future<void> _openTextById(String id) async {
    if (!mounted || _openedTextId == id) return;
    _openedTextId = id;
    LibraryText? match;
    final data = ref.read(libraryControllerProvider).value;
    if (data != null) {
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
    }
    match ??= await ref.read(libraryRepositoryProvider).fetchTextById(id);
    if (!mounted || match == null) {
      if (mounted && _openedTextId == id) _openedTextId = null;
      return;
    }
    final opened = match;
    setState(() {
      if (opened.sourceKind == LibraryTextSource.temporary) {
        _section = _LibrarySection.temporary;
      } else if (opened.sourceKind == LibraryTextSource.personal) {
        _section = _LibrarySection.personal;
      }
    });
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TextReadingPage(text: opened)),
    );
    if (mounted && _openedTextId == id) _openedTextId = null;
  }

  List<LibraryText> _textsFor(LibraryState state) {
    final source = switch (_section) {
      _LibrarySection.curated => state.texts,
      _LibrarySection.temporary => state.temporaryTexts,
      _LibrarySection.personal => state.personalTexts,
    };
    return [
      for (final text in source)
        if ((_languageFilter == null ||
                text.language.toUpperCase() == _languageFilter) &&
            (_cefrFilter == null || text.cefr == _cefrFilter))
          text,
    ];
  }

  List<String> _languageOptions(LibraryState state) {
    final study =
        ref.read(authControllerProvider).value?.studyLanguages ?? const [];
    final present = <String>{
      for (final text in [
        ...state.texts,
        ...state.temporaryTexts,
        ...state.personalTexts,
      ])
        text.language.toUpperCase(),
    };
    final seen = <String>{};
    final out = <String>[];
    void add(String code) {
      final upper = code.toUpperCase();
      if (upper.isEmpty || seen.contains(upper)) return;
      seen.add(upper);
      out.add(upper);
    }

    for (final code in study) {
      add(code);
    }
    for (final code in present) {
      add(code);
    }
    return out;
  }

  List<String> _cefrOptions(LibraryState state) {
    final levels = <String>{
      for (final text in [
        ...state.texts,
        ...state.temporaryTexts,
        ...state.personalTexts,
      ])
        if (text.cefr != null && text.cefr!.trim().isNotEmpty) text.cefr!.trim(),
    };
    const order = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    return [
      for (final level in order)
        if (levels.contains(level)) level,
      for (final level in levels)
        if (!order.contains(level)) level,
    ];
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: false,
      floatingActionButton: const NotebookFab(),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: 'Biblioteca',
              trailing: _LibraryHeaderButton(
                icon: LucideIcons.clipboard_paste,
                tooltip: 'Colar texto',
                onPressed: _pasteTemporary,
              ),
            ),
            AppTextTabs<_LibrarySection>(
              selected: _section,
              onSelected: (value) => setState(() => _section = value),
              tabs: const [
                AppTextTab(value: _LibrarySection.curated, label: 'Curada'),
                AppTextTab(
                  value: _LibrarySection.temporary,
                  label: 'Temporárias',
                ),
                AppTextTab(value: _LibrarySection.personal, label: 'Pessoais'),
              ],
            ),
            Expanded(
              child: stateAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => _LibraryEmptyState(
                  message:
                      'Não foi possível carregar a biblioteca.\n$error',
                ),
                data: (libraryState) {
                  final texts = _textsFor(libraryState);
                  final languages = _languageOptions(libraryState);
                  final cefrs = _cefrOptions(libraryState);
                  final mine =
                      ref.watch(vocabularyControllerProvider).value ??
                      const <VocabularyEntry>[];
                  final studyLanguages =
                      ref.watch(authControllerProvider).value?.studyLanguages ??
                      const <String>[];
                  final groups = _groupsFor(texts);
                  final filtered =
                      _languageFilter != null || _cefrFilter != null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.sm,
                          AppSpacing.xl,
                          AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            if (languages.isNotEmpty)
                              AppFilterMenu<String?>(
                                label: 'Idioma',
                                selected: _languageFilter,
                                onSelected: (value) => setState(
                                  () => _languageFilter = value,
                                ),
                                options: [
                                  const AppChoiceOption(
                                    value: null,
                                    label: 'Todos',
                                  ),
                                  for (final code in languages)
                                    AppChoiceOption(
                                      value: code,
                                      label: taughtLanguages[code] ?? code,
                                    ),
                                ],
                              ),
                            const Spacer(),
                            if (cefrs.isNotEmpty)
                              AppFilterMenu<String?>(
                                label: 'Nível',
                                selected: _cefrFilter,
                                onSelected: (value) =>
                                    setState(() => _cefrFilter = value),
                                options: [
                                  const AppChoiceOption(
                                    value: null,
                                    label: 'Todos',
                                  ),
                                  for (final level in cefrs)
                                    AppChoiceOption(
                                      value: level,
                                      label: level,
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: texts.isEmpty
                            ? _LibraryEmptyState(
                                message: filtered
                                    ? 'Nenhum texto nesse filtro.'
                                    : _emptyMessage,
                                actionLabel:
                                    _section == _LibrarySection.temporary &&
                                        !filtered
                                    ? 'Colar um texto'
                                    : null,
                                onAction:
                                    _section == _LibrarySection.temporary &&
                                        !filtered
                                    ? _pasteTemporary
                                    : null,
                              )
                            : ListView.separated(
                                padding: _libraryBodyPadding,
                                itemCount: groups.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppSpacing.md),
                                itemBuilder: (context, index) {
                                  final group = groups[index];
                                  return _LibraryEntryCard(
                                    title: group.title,
                                    subtitle: _subtitleFor(group, mine),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => TextReadingPage(
                                          text: group.preferred(
                                            _languageFilter == null
                                                ? studyLanguages
                                                : [_languageFilter!],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }

  List<_LibraryGroup> _groupsFor(List<LibraryText> texts) {
    if (_section != _LibrarySection.curated) {
      return [for (final text in texts) _LibraryGroup([text])];
    }
    final byTitle = <String, List<LibraryText>>{};
    for (final text in texts) {
      byTitle.putIfAbsent(text.title.trim().toLowerCase(), () => []).add(text);
    }
    return [for (final versions in byTitle.values) _LibraryGroup(versions)];
  }

  String _subtitleFor(_LibraryGroup group, List<VocabularyEntry> mine) {
    final languageCount = group.languageCount;
    final inList = group.inListCount(mine);
    final languageLabel = languageCount == 1
        ? (taughtLanguages[group.versions.first.language] ??
              group.versions.first.language)
        : '$languageCount idiomas';
    final parts = <String>[
      languageLabel,
      if (group.cefr != null) group.cefr!,
      '$inList na sua lista',
    ];
    final first = group.versions.first;
    if (first.sourceKind == LibraryTextSource.temporary &&
        first.expiresAt != null) {
      parts.add('expira em ${first.formatExpiresIn()}');
    }
    return parts.join(' · ');
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

class _LibraryHeaderButton extends StatelessWidget {
  const _LibraryHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
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
            child: Icon(icon, size: 18, color: AppColors.heading),
          ),
        ),
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _libraryBodyPadding,
      children: [
        AppSurface(
          borderRadius: _libraryCardRadius,
          padding: _libraryCardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryGroup {
  const _LibraryGroup(this.versions);

  final List<LibraryText> versions;

  String get title => versions.first.title;

  int get languageCount => versions.map((text) => text.language).toSet().length;

  String? get cefr {
    final values = versions.map((text) => text.cefr).whereType<String>().toSet();
    if (values.isEmpty) return null;
    if (values.length == 1) return values.first;
    return versions.first.cefr;
  }

  LibraryText preferred(List<String> studyLanguages) {
    for (final language in studyLanguages) {
      for (final text in versions) {
        if (text.language == language) return text;
      }
    }
    return versions.first;
  }

  int inListCount(List<VocabularyEntry> mine) {
    if (mine.isEmpty) return 0;
    var count = 0;
    for (final word in mine) {
      final term = word.term.trim().toLowerCase();
      if (term.isEmpty) continue;
      for (final text in versions) {
        if (word.language != text.language) continue;
        if (text.content.toLowerCase().contains(term)) {
          count++;
          break;
        }
      }
    }
    return count;
  }
}

class _LibraryEntryCard extends StatelessWidget {
  const _LibraryEntryCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      onTap: onTap,
      borderRadius: _libraryCardRadius,
      padding: _libraryCardPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              LucideIcons.chevron_right,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
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
