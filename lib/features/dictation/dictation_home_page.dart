import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vocabulary/models/vocabulary_entry.dart';
import 'dictation_controller.dart';
import 'dictation_session_page.dart';

class DictationHomePage extends ConsumerStatefulWidget {
  const DictationHomePage({super.key});

  @override
  ConsumerState<DictationHomePage> createState() => _DictationHomePageState();
}

class _DictationHomePageState extends ConsumerState<DictationHomePage> {
  String _language = 'EN';
  bool _loading = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(dictationRepositoryProvider).fetchFreeItems(language: _language);
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() => _error = 'Não há frases de ditado pra esse idioma ainda.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DictationSessionPage(items: items)),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível carregar as frases. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ditado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.headphones, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Ouça a frase e digite exatamente o que você ouviu.',
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
                onChanged: (value) => setState(() => _language = value ?? _language),
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
                    : const Text('Começar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
