import 'dart:math';

import '../../core/supabase_client.dart';
import 'models/dictation_item.dart';
import 'models/dictation_next_result.dart';
import 'models/dictation_score.dart';

const _itemColumns =
    'id, prompt_text, prompt_translation, language, cefr, topic, practice_tags';

/// Espelha o modo "prática livre" (sem atividade de professor, sem sessão
/// calibrada por IA) de `src/pages/student/DictationPage.tsx`: pool público
/// (`is_free_practice = true`), áudio gerado sob demanda via a edge function
/// `tts-generate`, e correção só local (`scoreDictationAnswer`) — sem chamar
/// `dictation-grade` (IA) nesta fatia.
class DictationRepository {
  const DictationRepository(this._studentId);

  final String _studentId;

  Future<List<DictationItem>> fetchFreeItems({
    required String language,
    int limit = 8,
  }) async {
    final rows = await supabase
        .from('dictation_items')
        .select(_itemColumns)
        .eq('is_free_practice', true)
        .eq('language', language)
        .order('created_at', ascending: false)
        .limit(50);
    final items = (rows as List)
        .map((row) => DictationItem.fromRow(row as Map<String, dynamic>))
        .toList();
    items.shuffle(Random());
    return items.take(limit).toList();
  }

  Future<DictationNextResult?> fetchCalibratedNext({
    required String language,
    String? cefr,
    List<String> focusTags = const [],
    int sessionSize = 10,
  }) async {
    try {
      final response = await supabase.functions
          .invoke(
            'dictation-next',
            body: {
              'language': language,
              'uiLanguage': 'pt',
              'sessionSize': sessionSize,
              if (cefr != null && cefr.isNotEmpty) 'cefr': cefr,
              if (focusTags.isNotEmpty) 'focusTags': focusTags,
            },
          )
          .timeout(const Duration(seconds: 45));
      final data = response.data;
      if (data is! Map) return null;
      return DictationNextResult.fromRow(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  Future<List<DictationItem>> fetchItemsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await supabase
        .from('dictation_items')
        .select(_itemColumns)
        .inFilter('id', ids);
    final byId = {
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        row['id'] as String: DictationItem.fromRow(row),
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<String?> fetchAudioUrl({
    required String text,
    required String language,
  }) async {
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
    if (data is Map && data['audioUrl'] is String) {
      return data['audioUrl'] as String;
    }
    return null;
  }

  Future<String?> saveAttempt({
    required String dictationItemId,
    required String answerText,
    required DictationGradingResult score,
  }) async {
    final row = await supabase
        .from('dictation_attempts')
        .insert({
          'dictation_item_id': dictationItemId,
          'activity_id': null,
          'student_id': _studentId,
          'answer_text': answerText,
          'score': score.score,
          'mistakes': score.mistakes.map((m) => m.toJson()).toList(),
          'feedback': score.feedback,
          'grading_source': score.source,
          'play_count': 1,
          'slow_play_count': 1,
        })
        .select('id')
        .single();
    return row['id'] as String?;
  }

  Future<void> diagnoseAttempt({
    required DictationItem item,
    required String answer,
    required DictationGradingResult score,
    String? attemptId,
  }) async {
    try {
      await supabase.functions
          .invoke(
            'dictation-diagnose',
            body: {
              'expected': item.promptText,
              'answer': answer,
              'language': item.language,
              'score': score.score,
              'mistakes': score.mistakes.map((m) => m.toJson()).toList(),
              'feedback': score.feedback,
              'cefr': item.cefr,
              'topic': item.topic ?? 'general',
              'attempt_id': attemptId,
              'dictation_item_id': item.id,
              'practice_tags': item.practiceTags,
              'uiLanguage': 'pt',
            },
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  Future<DictationReinforceResult?> fetchReinforce({
    required DictationItem item,
    required String answer,
    required DictationGradingResult score,
  }) async {
    try {
      final response = await supabase.functions
          .invoke(
            'dictation-reinforce',
            body: {
              'expected': item.promptText,
              'answer': answer,
              'language': item.language,
              'score': score.score,
              'mistakes': score.mistakes.map((m) => m.toJson()).toList(),
              'feedback': score.feedback,
              'cefr': item.cefr,
              'topic': item.topic ?? 'general',
              'uiLanguage': 'pt',
            },
          )
          .timeout(const Duration(seconds: 12));
      final data = response.data;
      if (data is! Map) return null;
      return DictationReinforceResult.fromRow(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// Chama a edge function `dictation-grade` (IA) — o resultado é combinado
  /// com a nota local via `mergeDictationGrades`; nunca substitui sozinho.
  /// `null` (erro/timeout) faz `mergeDictationGrades` cair pro local, igual
  /// ao web.
  Future<Map<String, dynamic>?> fetchAiGrade({
    required String expected,
    required String answer,
    required String language,
    required DictationScoreResult local,
  }) async {
    try {
      final response = await supabase.functions
          .invoke(
            'dictation-grade',
            body: {
              'expected': expected,
              'answer': answer,
              'language': language,
              'localScore': local.score,
              'localMistakes': local.mistakes.map((m) => m.toJson()).toList(),
              'uiLanguage': 'pt',
            },
          )
          .timeout(const Duration(seconds: 8));
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }
}
