import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/learner_routes.dart';
import '../../core/session/app_role.dart';

import '../../core/session/app_user.dart';
import '../notebook/notebook_fab.dart';
import '../../core/session/auth_controller.dart';
import '../placement/models/placement_retake_status.dart';
import '../placement/placement_controller.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'profile_repository.dart';
import 'skill_progress_repository.dart';

/// Espelha a aba "study" de `SubscriberProfilePage.tsx`: dados da conta,
/// idiomas, nível CEFR, cooldown de retake e progresso de skills.
class SubscriberProfilePage extends ConsumerStatefulWidget {
  const SubscriberProfilePage({super.key});

  @override
  ConsumerState<SubscriberProfilePage> createState() =>
      _SubscriberProfilePageState();
}

class _SubscriberProfilePageState extends ConsumerState<SubscriberProfilePage> {
  final _nameController = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  String? _error;
  bool _savedOk = false;
  Set<String> _selectedLanguages = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _beginEdit(AppUser user) {
    setState(() {
      _nameController.text = user.name;
      _selectedLanguages = user.studyLanguages.toSet();
      _error = null;
      _savedOk = false;
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _error = null;
      _editing = false;
    });
  }

  void _toggleLanguage(String code) {
    setState(() {
      if (_selectedLanguages.contains(code)) {
        if (_selectedLanguages.length > 1) _selectedLanguages.remove(code);
      } else {
        _selectedLanguages.add(code);
      }
      _savedOk = false;
    });
  }

  Future<void> _save(AppUser user) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe seu nome.');
      return;
    }
    if (_selectedLanguages.isEmpty) {
      setState(() => _error = 'Escolha ao menos um idioma de estudo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await const ProfileRepository().updateProfile(
        userId: user.id,
        fullName: name,
        studyLanguages: _selectedLanguages.toList(),
      );
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      setState(() {
        _editing = false;
        _savedOk = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      floatingActionButton: const NotebookFab(),
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => _beginEdit(user),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Dados da conta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_editing)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
              )
            else
              _ReadOnlyField(label: 'Nome', value: user.name),
            const SizedBox(height: 12),
            _ReadOnlyField(label: 'E-mail', value: user.email),
            const SizedBox(height: 24),
            Text(
              'Idiomas de estudo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _editing
                  ? [
                      for (final entry in taughtLanguages.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: _selectedLanguages.contains(entry.key),
                          onSelected: (_) => _toggleLanguage(entry.key),
                        ),
                    ]
                  : (user.studyLanguages.isEmpty
                        ? [const Text('Nenhum idioma de estudo definido.')]
                        : [
                            for (final code in user.studyLanguages)
                              Chip(label: Text(taughtLanguages[code] ?? code)),
                          ]),
            ),
            if (_editing) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : () => _save(user),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _saving ? null : _cancelEdit,
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
            if (_savedOk) ...[
              const SizedBox(height: 12),
              Text(
                'Salvo!',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 28),
            Text(
              'Nível por idioma',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (user.studyLanguages.isEmpty)
              const Text('Defina um idioma de estudo pra ver o nível.')
            else
              for (final code in user.studyLanguages)
                _LevelRow(code: code, user: user),
            if (user.studyLanguages.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text(
                'Progresso por habilidade',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Coroas acumuladas a partir de ditado, vocabulário e nivelamento.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final code in user.studyLanguages)
                _SkillProgressBlock(language: code),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(value.isEmpty ? '—' : value),
      ],
    );
  }
}

class _LevelRow extends ConsumerStatefulWidget {
  const _LevelRow({required this.code, required this.user});

  final String code;
  final AppUser user;

  @override
  ConsumerState<_LevelRow> createState() => _LevelRowState();
}

class _LevelRowState extends ConsumerState<_LevelRow> {
  PlacementRetakeStatus? _retake;

  @override
  void initState() {
    super.initState();
    _loadRetake();
  }

  Future<void> _loadRetake() async {
    final status = await ref
        .read(placementRepositoryProvider)
        .fetchCanRetake(language: widget.code, isStudent: false);
    if (mounted) setState(() => _retake = status);
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.user.cefrLevelByLanguage[widget.code];
    final blocked = _retake?.allowed == false;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(taughtLanguages[widget.code] ?? widget.code),
        subtitle: Text(
          [
            level != null ? 'Nível $level' : 'Nivelamento pendente',
            if (blocked) _retake!.blockedMessage,
          ].join('\n'),
        ),
        isThreeLine: blocked,
        trailing: TextButton(
          onPressed: () => context.push(
            LearnerPaths.placement(AppRole.subscriber, lang: widget.code),
          ),
          child: Text(level != null ? 'Refazer' : 'Fazer nivelamento'),
        ),
      ),
    );
  }
}

class _SkillProgressBlock extends ConsumerStatefulWidget {
  const _SkillProgressBlock({required this.language});

  final String language;

  @override
  ConsumerState<_SkillProgressBlock> createState() =>
      _SkillProgressBlockState();
}

class _SkillProgressBlockState extends ConsumerState<_SkillProgressBlock> {
  bool _loading = true;
  List<SkillProgressRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await const SkillProgressRepository().fetch(widget.language);
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      // Sem progresso ainda — a seção fica vazia.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Ainda sem dados em ${taughtLanguages[widget.language] ?? widget.language}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            taughtLanguages[widget.language] ?? widget.language,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(row.label)),
                  Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(
                          i < row.crownLevel
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: 12,
                          color: i < row.crownLevel
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
