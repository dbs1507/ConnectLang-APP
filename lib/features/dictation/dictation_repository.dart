import 'dart:math';

import '../../core/supabase_client.dart';
import 'models/dictation_item.dart';
import 'models/dictation_score.dart';

const _itemColumns = 'id, prompt_text, prompt_translation, language, cefr';

/// Espelha o modo "prática livre" (sem atividade de professor, sem sessão
/// calibrada por IA) de `src/pages/student/DictationPage.tsx`: pool público
/// (`is_free_practice = true`), áudio gerado sob demanda via a edge function
/// `tts-generate`, e correção só local (`scoreDictationAnswer`) — sem chamar
/// `dictation-grade` (IA) nesta fatia.
class DictationRepository {
  const DictationRepository(this._studentId);

  final String _studentId;

  Future<List<DictationItem>> fetchFreeItems({required String language, int limit = 8}) async {
    final rows = await supabase
        .from('dictation_items')
        .select(_itemColumns)
        .eq('is_free_practice', true)
        .eq('language', language)
        .order('created_at', ascending: false)
        .limit(50);
    final items = (rows as List).map((row) => DictationItem.fromRow(row as Map<String, dynamic>)).toList();
    items.shuffle(Random());
    return items.take(limit).toList();
  }

  Future<String?> fetchAudioUrl({required String text, required String language}) async {
    final response = await supabase.functions.invoke(
      'tts-generate',
      body: {
        'text': text,
        'language': language,
        'origin': 'base',
        'voiceGender': 'female',
        'delivery': 'url',
      },
    );
    final data = response.data;
    if (data is Map && data['audioUrl'] is String) return data['audioUrl'] as String;
    return null;
  }

  Future<void> saveAttempt({
    required String dictationItemId,
    required String answerText,
    required DictationScoreResult score,
  }) async {
    await supabase.from('dictation_attempts').insert({
      'dictation_item_id': dictationItemId,
      'activity_id': null,
      'student_id': _studentId,
      'answer_text': answerText,
      'score': score.score,
      'mistakes': score.mistakes.map((m) => m.toJson()).toList(),
      'feedback': null,
      'grading_source': 'local',
      'play_count': 1,
      'slow_play_count': 1,
    });
  }
}
