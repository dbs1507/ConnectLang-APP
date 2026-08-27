import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_controller.dart';
import 'models/text_question.dart';

/// Espelha o fluxo de responder o `TextQuestionSet` publicado em
/// `StudentTextLibraryPage.tsx` — só MCQ, sem revisão de tentativa anterior
/// nem gabarito comentado (o web mostra ambos; fica pra próxima fatia).
class TextQuestionsPage extends ConsumerStatefulWidget {
  const TextQuestionsPage({super.key, required this.questionSet});

  final TextQuestionSet questionSet;

  @override
  ConsumerState<TextQuestionsPage> createState() => _TextQuestionsPageState();
}

class _TextQuestionsPageState extends ConsumerState<TextQuestionsPage> {
  final Map<String, String> _selected = {};
  bool _submitting = false;
  String? _error;
  ({int correct, int total})? _result;

  Future<void> _submit() async {
    if (_selected.length < widget.questionSet.questions.length) {
      setState(() => _error = 'Responda todas as perguntas antes de enviar.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(libraryRepositoryProvider).submitQuestionAttempt(
            set: widget.questionSet,
            selectedByQuestionId: _selected,
          );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível enviar suas respostas. Tente novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Perguntas de compreensão')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (result != null) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Você acertou ${result.correct} de ${result.total}.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final question in widget.questionSet.questions) ...[
              Text(question.prompt, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _selected[question.id],
                onChanged: result != null
                    ? (_) {}
                    : (value) => setState(() {
                          if (value != null) _selected[question.id] = value;
                        }),
                child: Column(
                  children: [
                    for (final option in question.options)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(option.text),
                        value: option.key,
                        enabled: result == null,
                        selected: _selected[question.id] == option.key,
                        activeColor: result == null
                            ? null
                            : (option.isCorrect
                                ? Colors.green
                                : (option.key == _selected[question.id] ? Theme.of(context).colorScheme.error : null)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            if (result == null)
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enviar respostas'),
              )
            else
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
          ],
        ),
      ),
    );
  }
}
