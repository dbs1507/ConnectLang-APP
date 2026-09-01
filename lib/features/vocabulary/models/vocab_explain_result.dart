/// Porte de `VocabExplainResult` (`src/lib/vocabExplain.ts`).
class VocabExplainResult {
  const VocabExplainResult({
    required this.explanation,
    required this.whyHard,
    required this.examples,
    required this.tip,
    required this.source,
  });

  final String explanation;
  final String whyHard;
  final List<String> examples;
  final String tip;
  final String source;

  static VocabExplainResult? fromRow(Map<String, dynamic> row) {
    final explanation = (row['explanation'] as String? ?? '').trim();
    if (explanation.isEmpty) return null;
    final rawExamples = row['examples'];
    return VocabExplainResult(
      explanation: explanation,
      whyHard: (row['whyHard'] as String? ?? '').trim(),
      examples: rawExamples is List
          ? rawExamples
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .take(3)
                .toList()
          : const [],
      tip: (row['tip'] as String? ?? '').trim(),
      source: row['source'] == 'fallback' ? 'fallback' : 'ai',
    );
  }

  String notebookTitle(String term) =>
      'Explicação: ${term.length > 80 ? '${term.substring(0, 80)}…' : term}';

  String notebookContent() {
    final lines = [
      explanation,
      if (whyHard.isNotEmpty) 'Por que é difícil: $whyHard',
      if (examples.isNotEmpty)
        ['Exemplos:', ...examples.map((e) => '• $e')].join('\n'),
      if (tip.isNotEmpty) 'Dica: $tip',
    ];
    return lines.join('\n\n');
  }
}
