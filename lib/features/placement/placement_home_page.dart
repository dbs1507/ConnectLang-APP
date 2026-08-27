import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/app_role.dart';
import '../../core/session/auth_controller.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'models/placement_result.dart';
import 'models/placement_retake_status.dart';
import 'placement_controller.dart';
import 'placement_session_page.dart';

/// Espelha a fase "choose" de `src/pages/student/PlacementPage.tsx`: os dois
/// caminhos ("Descobrir meu nível" e "Começar do zero"), com a mesma checagem
/// de cooldown de retake do web. Fora do escopo: pedido de retake pro
/// professor e o atalho pra sugestão do Coach.
class PlacementHomePage extends ConsumerStatefulWidget {
  const PlacementHomePage({super.key});

  @override
  ConsumerState<PlacementHomePage> createState() => _PlacementHomePageState();
}

class _PlacementHomePageState extends ConsumerState<PlacementHomePage> {
  String _language = 'EN';
  bool _loading = false;
  bool _checkingRetake = true;
  String? _error;
  PlacementRetakeStatus? _retakeStatus;

  @override
  void initState() {
    super.initState();
    _refreshRetakeStatus();
  }

  bool get _isStudent => ref.read(authControllerProvider).value?.role == AppRole.student;

  Future<void> _refreshRetakeStatus() async {
    setState(() => _checkingRetake = true);
    try {
      final status = await ref
          .read(placementRepositoryProvider)
          .fetchCanRetake(language: _language, isStudent: _isStudent);
      if (mounted) setState(() => _retakeStatus = status);
    } finally {
      if (mounted) setState(() => _checkingRetake = false);
    }
  }

  void _changeLanguage(String? value) {
    if (value == null || value == _language || _loading) return;
    setState(() {
      _language = value;
      _retakeStatus = null;
    });
    _refreshRetakeStatus();
  }

  Future<void> _start() async {
    if (_retakeStatus?.allowed == false) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(placementRepositoryProvider);
      final ready = await repo.isLanguageReady(_language);
      if (!ready) {
        setState(() => _error = 'O teste deste idioma ainda está em preparação.');
        return;
      }
      final PlacementStepResult result = await repo.startTest(_language);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlacementSessionPage(initial: result)),
      );
      if (mounted) unawaited(_refreshRetakeStatus());
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível iniciar o nivelamento. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startZero() async {
    if (_retakeStatus?.allowed == false) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(placementRepositoryProvider).startZero(_language);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nível definido como ${result.resultCefr ?? 'A1'}!')),
      );
      unawaited(_refreshRetakeStatus());
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível começar do zero. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _retakeStatus?.allowed == false;
    final busy = _loading || _checkingRetake;

    return Scaffold(
      appBar: AppBar(title: const Text('Nivelamento')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.school_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Teste adaptativo de vocabulário, gramática e compreensão oral pra descobrir seu nível (CEFR) neste idioma.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Idioma'),
                items: [
                  for (final entry in taughtLanguages.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: _loading ? null : _changeLanguage,
              ),
              if (blocked) ...[
                const SizedBox(height: 12),
                Text(
                  _retakeStatus!.blockedMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (busy || blocked) ? null : _start,
                child: (_loading || _checkingRetake)
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Descobrir meu nível'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: (busy || blocked) ? null : _startZero,
                child: const Text('Começar do zero (A1)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
