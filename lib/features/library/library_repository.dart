import '../../core/supabase_client.dart';
import 'models/library_text.dart';
import 'models/text_question.dart';

const _textColumns = 'id, title, content, language, cefr, tags, created_at';

const _questionSetColumns = '''
  id,
  text_questions (
    id, question_type, order_index, prompt, correct_option_key,
    text_question_options ( option_key, option_text, is_correct )
  )
''';

/// Espelha as partes de `StudentTextLibraryPage.tsx` usadas nesta fatia:
/// listar `texts_library` (visível pra qualquer aluno/assinante autenticado,
/// sem gate por CEFR) e marcar/desmarcar leitura em `student_text_reads`.
class LibraryRepository {
  const LibraryRepository(this._studentId);

  final String _studentId;

  Future<List<LibraryText>> fetchTexts() async {
    final rows = await supabase.from('texts_library').select(_textColumns).order('created_at', ascending: false);
    return (rows as List).map((row) => LibraryText.fromRow(row as Map<String, dynamic>)).toList();
  }

  Future<Set<String>> fetchReadTextIds() async {
    final rows = await supabase.from('student_text_reads').select('text_id').eq('student_id', _studentId);
    return (rows as List).map((row) => row['text_id'] as String).toSet();
  }

  Future<void> markRead(String textId) async {
    await supabase.from('student_text_reads').insert({'student_id': _studentId, 'text_id': textId});
  }

  Future<void> markUnread(String textId) async {
    await supabase.from('student_text_reads').delete().eq('student_id', _studentId).eq('text_id', textId);
  }

  /// Último conjunto de perguntas publicado pelo professor pra esse texto —
  /// `null` se nenhum professor ainda gerou/publicou perguntas.
  Future<TextQuestionSet?> fetchQuestionSet(String textId) async {
    final row = await supabase
        .from('text_question_sets')
        .select(_questionSetColumns)
        .eq('source_type', 'library')
        .eq('source_id', textId)
        .eq('status', 'published')
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return TextQuestionSet.fromRow(row);
  }

  /// Espelha `submitStudentAttempt` — só MCQ (a IA nunca gera pergunta aberta).
  Future<({int correct, int total})> submitQuestionAttempt({
    required TextQuestionSet set,
    required Map<String, String> selectedByQuestionId,
  }) async {
    var correct = 0;
    for (final question in set.questions) {
      if (selectedByQuestionId[question.id] == question.correctOptionKey) correct += 1;
    }
    final attempt = await supabase
        .from('student_text_question_attempts')
        .insert({
          'student_id': _studentId,
          'question_set_id': set.id,
          'score_correct': correct,
          'score_total': set.questions.length,
          'is_completed': true,
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    await supabase.from('student_text_question_answers').insert([
      for (final question in set.questions)
        {
          'attempt_id': attempt['id'],
          'question_id': question.id,
          'selected_option_key': selectedByQuestionId[question.id],
          'is_correct': selectedByQuestionId[question.id] == question.correctOptionKey,
        },
    ]);

    return (correct: correct, total: set.questions.length);
  }

  /// Espelha `fetchTextTtsPlan` (edge function `tts-text-plan`) — o texto
  /// vem em pedaços (parágrafos/sentenças) já sintetizados em base64, cada
  /// um tocado em sequência. Sem cache local nem controle de velocidade/voz
  /// nesta fatia (sempre voz feminina, igual ao padrão do Ditado/Nivelamento).
  Future<List<Map<String, dynamic>>> fetchTtsChunks(String textId) async {
    final response = await supabase.functions.invoke(
      'tts-text-plan',
      body: {'libraryTextId': textId, 'voiceGender': 'female'},
    );
    final data = response.data;
    final chunks = data is Map ? data['chunks'] : null;
    if (chunks is! List) return const [];
    final result = chunks.whereType<Map>().map((c) => Map<String, dynamic>.from(c)).toList();
    result.sort((a, b) => ((a['idx'] as num?) ?? 0).compareTo((b['idx'] as num?) ?? 0));
    return result;
  }
}
