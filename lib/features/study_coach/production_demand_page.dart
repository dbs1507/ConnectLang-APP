import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/production_assignment.dart';
import 'study_coach_controller.dart';

/// Espelha `src/pages/student/ProductionDemandPage.tsx` — tarefa de produção
/// avulsa sugerida pelo Study Coach. Carrega a assignment por id, o aluno
/// escreve e envia pra correção (`correct-sentence`, mesma edge function do
/// site), que já marca a assignment como `done` no servidor.
class ProductionDemandPage extends ConsumerStatefulWidget {
  const ProductionDemandPage({super.key, required this.assignmentId});

  final String assignmentId;

  @override
  ConsumerState<ProductionDemandPage> createState() => _ProductionDemandPageState();
}

class _ProductionDemandPageState extends ConsumerState<ProductionDemandPage> {
  final _textController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  ProductionAssignment? _assignment;

  bool _submitting = false;
  String? _submitError;
  CorrectSentenceResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final assignment = await ref.read(studyCoachRepositoryProvider).fetchAssignment(widget.assignmentId);
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        if (assignment == null) _loadError = 'Tarefa não encontrada.';
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Não foi possível carregar a tarefa.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final assignment = _assignment;
    if (assignment == null || _submitting) return;
    final sentence = _textController.text.trim();
    if (sentence.length < 20) {
      setState(() => _submitError = 'Escreva pelo menos algumas frases (mínimo 20 caracteres).');
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await ref.read(studyCoachRepositoryProvider).gradeProduction(
            sentence: sentence,
            language: assignment.language,
            cefr: assignment.targetCefr.isEmpty ? null : assignment.targetCefr,
            assignmentId: assignment.id,
          );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (_) {
      if (mounted) setState(() => _submitError = 'Não foi possível corrigir o texto. Tente novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produção sob demanda')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _assignment == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_loadError ?? 'Tarefa não encontrada.'),
                    ),
                  )
                : _buildContent(context, _assignment!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProductionAssignment assignment) {
    final done = assignment.isDone || _result != null;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          assignment.title.isNotEmpty ? assignment.title : 'Produção de texto',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (assignment.reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(assignment.reason, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text(assignment.language)),
            if (assignment.targetCefr.isNotEmpty) Chip(label: Text(assignment.targetCefr)),
          ],
        ),
        const SizedBox(height: 20),
        Text('Proposta', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(assignment.prompt),
        if (assignment.criteria.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Critérios', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(assignment.criteria, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 20),
        if (done && _result == null) ...[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(child: Text('Você já concluiu esta tarefa.')),
                ],
              ),
            ),
          ),
        ] else if (_result == null) ...[
          TextField(
            controller: _textController,
            minLines: 8,
            maxLines: 14,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: 'Escreva sua produção', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          if (_submitError != null) ...[
            Text(_submitError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
          ],
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enviar'),
          ),
        ],
        if (_result != null) _buildResult(context, _result!),
      ],
    );
  }

  Widget _buildResult(BuildContext context, CorrectSentenceResult result) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text('Correção', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              Text(result.explanation),
              if (!result.isAlreadyGood) ...[
                const SizedBox(height: 12),
                Text('Versão corrigida', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(result.corrected),
                ),
              ],
              if (result.issues.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final issue in result.issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${issue.span} → ${issue.fix}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (issue.note.isNotEmpty) Text(issue.note, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
              ],
              if (result.naturalAlternative.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Forma natural', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(result.naturalAlternative),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
