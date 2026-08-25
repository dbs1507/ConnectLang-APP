import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vocabulary/models/vocabulary_entry.dart';
import 'models/placement_result.dart';
import 'placement_controller.dart';
import 'placement_session_page.dart';

/// Espelha a fase "choose" de `src/pages/student/PlacementPage.tsx`, só o
/// caminho "Descobrir meu nível" (teste adaptativo) — "Começar do zero" e o
/// fluxo de fila de idiomas pendentes ficam de fora desta fatia.
class PlacementHomePage extends ConsumerStatefulWidget {
  const PlacementHomePage({super.key});

  @override
  ConsumerState<PlacementHomePage> createState() => _PlacementHomePageState();
}

class _PlacementHomePageState extends ConsumerState<PlacementHomePage> {
  String _language = 'EN';
  bool _loading = false;
  String? _error;

  Future<void> _start() async {
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
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível iniciar o nivelamento. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onChanged: _loading ? null : (value) => setState(() => _language = value ?? _language),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _start,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Descobrir meu nível'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
