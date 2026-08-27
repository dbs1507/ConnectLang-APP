/// Recorte de `src/lib/textQuestions.ts` — só o que o app lê: o conjunto de
/// perguntas MCQ já publicado por um professor pra um texto da biblioteca.
/// Geração por IA fica de fora aqui de propósito: a edge function
/// `text-questions-generate` só deixa professor/admin gerar perguntas pra
/// `source_type = 'library'` (só pra textos pessoais/temporários, fora de
/// escopo, o próprio aluno poderia gerar) — então o app só consome o que já
/// existe. Perguntas abertas (`question_type = 'open'`) nunca são geradas
/// pela IA (só criadas manualmente pelo professor) e ficam de fora.
class TextQuestionOption {
  const TextQuestionOption({required this.key, required this.text, required this.isCorrect});

  final String key;
  final String text;
  final bool isCorrect;

  factory TextQuestionOption.fromRow(Map<String, dynamic> row) {
    return TextQuestionOption(
      key: row['option_key'] as String? ?? '',
      text: row['option_text'] as String? ?? '',
      isCorrect: row['is_correct'] == true,
    );
  }
}

class TextQuestion {
  const TextQuestion({
    required this.id,
    required this.orderIndex,
    required this.prompt,
    required this.correctOptionKey,
    required this.options,
  });

  final String id;
  final int orderIndex;
  final String prompt;
  final String? correctOptionKey;
  final List<TextQuestionOption> options;

  static TextQuestion? fromRow(Map<String, dynamic> row) {
    if (row['question_type'] != 'mcq') return null;
    final rawOptions = row['text_question_options'];
    final options = rawOptions is List
        ? (rawOptions.whereType<Map>().map((o) => TextQuestionOption.fromRow(Map<String, dynamic>.from(o))).toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
        : <TextQuestionOption>[];
    if (options.isEmpty) return null;
    return TextQuestion(
      id: row['id'] as String,
      orderIndex: (row['order_index'] as num?)?.toInt() ?? 0,
      prompt: (row['prompt'] as String? ?? '').trim(),
      correctOptionKey: row['correct_option_key'] as String?,
      options: options,
    );
  }
}

class TextQuestionSet {
  const TextQuestionSet({required this.id, required this.questions});

  final String id;
  final List<TextQuestion> questions;

  static TextQuestionSet? fromRow(Map<String, dynamic> row) {
    final rawQuestions = row['text_questions'];
    final questions = rawQuestions is List
        ? (rawQuestions
                .whereType<Map>()
                .map((q) => TextQuestion.fromRow(Map<String, dynamic>.from(q)))
                .whereType<TextQuestion>()
                .toList()
              ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)))
        : <TextQuestion>[];
    if (questions.isEmpty) return null;
    return TextQuestionSet(id: row['id'] as String, questions: questions);
  }
}
