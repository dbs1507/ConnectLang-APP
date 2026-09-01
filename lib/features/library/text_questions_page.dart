import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../study_coach/study_assignments_repository.dart';
import 'library_controller.dart';
import 'models/text_question.dart';

/// Espelha o fluxo de responder o `TextQuestionSet` publicado em
/// `StudentTextLibraryPage.tsx`, incluindo revisão da última tentativa e
/// "tentar de novo".
class TextQuestionsPage extends ConsumerStatefulWidget {
  const TextQuestionsPage({
    super.key,
    required this.questionSet,
    required this.language,
    required this.textId,
  });

  final TextQuestionSet questionSet;
  final String language;
  final String textId;

  @override
  ConsumerState<TextQuestionsPage> createState() => _TextQuestionsPageState();
}

class _TextQuestionsPageState extends ConsumerState<TextQuestionsPage> {
  final Map<String, String> _selected = {};
  bool _submitting = false;
  bool _loadingAttempt = true;
  String? _error;
  ({int correct, int total})? _result;

  @override
  void initState() {
    super.initState();
    _loadLatestAttempt();
  }

  Future<void> _loadLatestAttempt() async {
    try {
      final attempt = await ref
          .read(libraryRepositoryProvider)
          .fetchLatestAttempt(widget.questionSet.id);
      if (!mounted) return;
      if (attempt != null) {
        setState(
          () => _result = (correct: attempt.correct, total: attempt.total),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAttempt = false);
    }
  }

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
      final result = await ref
          .read(libraryRepositoryProvider)
          .submitQuestionAttempt(
            set: widget.questionSet,
            selectedByQuestionId: _selected,
          );
      if (!mounted) return;
      setState(() => _result = result);
      unawaited(
        const StudyAssignmentsRepository().completeLibrary(
          language: widget.language,
          textId: widget.textId,
          kinds: const ['read_questions'],
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível enviar suas respostas. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _retry() {
    setState(() {
      _selected.clear();
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Perguntas de compreensão')),
      body: SafeArea(
        child: _loadingAttempt
            ? const Center(child: CircularProgressIndicator())
            : ListView(
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
                    Text(
                      question.prompt,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
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
                              title: Text(
                                option.text,
                                style: result != null && option.isCorrect
                                    ? const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      )
                                    : null,
                              ),
                              value: option.key,
                              enabled: result == null,
                              selected: _selected[question.id] == option.key,
                              activeColor: result == null
                                  ? null
                                  : (option.isCorrect
                                        ? Colors.green
                                        : (option.key == _selected[question.id]
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.error
                                              : null)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (result == null)
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enviar respostas'),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _retry,
                            child: const Text('Tentar de novo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Voltar'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
