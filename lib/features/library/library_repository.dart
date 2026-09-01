import '../../core/supabase_client.dart';
import 'models/inline_translation.dart';
import 'models/library_text.dart';
import 'models/text_question.dart';

const _textColumns = 'id, title, content, language, cefr, tags, created_at';

const _tempColumns =
    'id, student_id, title, content, language, cefr, tags, created_at, expires_at, saved_to_personal_text_id';

const _personalColumns =
    'id, student_id, title, content, language, cefr, tags, source_temporary_text_id, created_at, updated_at';

const _questionSetColumns = '''
  id,
  text_questions (
    id, question_type, order_index, prompt, correct_option_key,
    text_question_options ( option_key, option_text, is_correct )
  )
''';

const ownedTextMaxChars = 12000;
const ownedTextMaxTitle = 200;
const tempTextsPerDay = 5;
const personalTextsSoftCap = 30;
const tempTextTtl = Duration(hours: 48);

class OwnedTextException implements Exception {
  const OwnedTextException(this.code);

  final String code;

  @override
  String toString() => 'OwnedTextException($code)';
}

/// Espelha `StudentTextLibraryPage.tsx` + `ownedTexts.ts` + `textTts.ts` +
/// `textQuestions.ts` (leitura, textos próprios, TTS e perguntas).
class LibraryRepository {
  const LibraryRepository(this._studentId);

  final String _studentId;

  Future<List<LibraryText>> fetchTexts() async {
    final rows = await supabase
        .from('texts_library')
        .select(_textColumns)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => LibraryText.fromLibraryRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<LibraryText>> fetchTemporaryTexts() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await supabase
        .from('student_temporary_texts')
        .select(_tempColumns)
        .eq('student_id', _studentId)
        .isFilter('saved_to_personal_text_id', null)
        .gt('expires_at', nowIso)
        .order('expires_at');
    return (rows as List)
        .map((row) => LibraryText.fromTemporaryRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<LibraryText>> fetchPersonalTexts() async {
    final rows = await supabase
        .from('student_personal_texts')
        .select(_personalColumns)
        .eq('student_id', _studentId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => LibraryText.fromPersonalRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> fetchReadTextIds() async {
    final rows = await supabase
        .from('student_text_reads')
        .select('text_id')
        .eq('student_id', _studentId);
    return (rows as List).map((row) => row['text_id'] as String).toSet();
  }

  Future<void> markRead(String textId) async {
    await supabase.from('student_text_reads').insert({
      'student_id': _studentId,
      'text_id': textId,
    });
  }

  Future<void> markUnread(String textId) async {
    await supabase
        .from('student_text_reads')
        .delete()
        .eq('student_id', _studentId)
        .eq('text_id', textId);
  }

  Future<int> _countTemporaryCreatedToday() async {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day).toIso8601String();
    final rows = await supabase
        .from('student_temporary_texts')
        .select('id')
        .eq('student_id', _studentId)
        .gte('created_at', start);
    return (rows as List).length;
  }

  Future<LibraryText> createTemporaryText({
    required String title,
    required String content,
    required String language,
    String? cefr,
  }) async {
    final titleTrimmed = title.trim().isEmpty ? 'Sem título' : title.trim();
    final clippedTitle = titleTrimmed.length > ownedTextMaxTitle
        ? titleTrimmed.substring(0, ownedTextMaxTitle)
        : titleTrimmed;
    final clippedContent = content.trim().length > ownedTextMaxChars
        ? content.trim().substring(0, ownedTextMaxChars)
        : content.trim();
    if (clippedContent.isEmpty) throw const OwnedTextException('empty');

    final createdToday = await _countTemporaryCreatedToday();
    if (createdToday >= tempTextsPerDay) {
      throw const OwnedTextException('daily_limit');
    }

    final expiresAt = DateTime.now().toUtc().add(tempTextTtl).toIso8601String();
    final row = await supabase
        .from('student_temporary_texts')
        .insert({
          'student_id': _studentId,
          'title': clippedTitle,
          'content': clippedContent,
          'language': language,
          'cefr': cefr?.trim().isNotEmpty == true ? cefr!.trim() : null,
          'tags': <String>[],
          'expires_at': expiresAt,
        })
        .select(_tempColumns)
        .single();
    return LibraryText.fromTemporaryRow(row);
  }

  Future<LibraryText> saveTemporaryToPersonal(String temporaryTextId) async {
    final temp = await supabase
        .from('student_temporary_texts')
        .select(_tempColumns)
        .eq('id', temporaryTextId)
        .eq('student_id', _studentId)
        .maybeSingle();
    if (temp == null) throw const OwnedTextException('not_found');
    if (temp['saved_to_personal_text_id'] != null) {
      throw const OwnedTextException('already_saved');
    }
    final expiresAt = DateTime.tryParse(temp['expires_at'] as String? ?? '');
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      throw const OwnedTextException('expired');
    }

    final personalRows = await supabase
        .from('student_personal_texts')
        .select('id')
        .eq('student_id', _studentId);
    if ((personalRows as List).length >= personalTextsSoftCap) {
      throw const OwnedTextException('personal_cap');
    }

    final personal = await supabase
        .from('student_personal_texts')
        .insert({
          'student_id': _studentId,
          'title': temp['title'],
          'content': temp['content'],
          'language': temp['language'],
          'cefr': temp['cefr'],
          'tags': temp['tags'] ?? <String>[],
          'source_temporary_text_id': temp['id'],
        })
        .select(_personalColumns)
        .single();

    await supabase
        .from('student_temporary_texts')
        .update({'saved_to_personal_text_id': personal['id']})
        .eq('id', temp['id'])
        .eq('student_id', _studentId);

    try {
      await supabase.rpc(
        'transfer_temporary_text_question_sets',
        params: {
          'p_temporary_text_id': temp['id'],
          'p_personal_text_id': personal['id'],
        },
      );
    } catch (_) {}

    return LibraryText.fromPersonalRow(personal);
  }

  Future<void> deleteTemporaryText(String textId) async {
    await supabase
        .from('student_temporary_texts')
        .delete()
        .eq('id', textId)
        .eq('student_id', _studentId)
        .isFilter('saved_to_personal_text_id', null);
  }

  Future<void> deletePersonalText(String textId) async {
    await supabase
        .from('student_personal_texts')
        .delete()
        .eq('id', textId)
        .eq('student_id', _studentId);
  }

  Future<TextQuestionSet?> fetchQuestionSet(
    String textId, {
    String sourceType = 'library',
  }) async {
    final row = await supabase
        .from('text_question_sets')
        .select(_questionSetColumns)
        .eq('source_type', sourceType)
        .eq('source_id', textId)
        .eq('status', 'published')
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return TextQuestionSet.fromRow(row);
  }

  Future<StudentQuestionAttempt?> fetchLatestAttempt(
    String questionSetId,
  ) async {
    final row = await supabase
        .from('student_text_question_attempts')
        .select('id, score_correct, score_total, submitted_at')
        .eq('student_id', _studentId)
        .eq('question_set_id', questionSetId)
        .eq('is_completed', true)
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return StudentQuestionAttempt(
      id: row['id'] as String,
      correct: (row['score_correct'] as num?)?.toInt() ?? 0,
      total: (row['score_total'] as num?)?.toInt() ?? 0,
      submittedAt: DateTime.tryParse(row['submitted_at'] as String? ?? ''),
    );
  }

  Future<({int correct, int total})> submitQuestionAttempt({
    required TextQuestionSet set,
    required Map<String, String> selectedByQuestionId,
  }) async {
    var correct = 0;
    for (final question in set.questions) {
      if (selectedByQuestionId[question.id] == question.correctOptionKey) {
        correct += 1;
      }
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
          'is_correct':
              selectedByQuestionId[question.id] == question.correctOptionKey,
        },
    ]);

    return (correct: correct, total: set.questions.length);
  }

  Future<TextQuestionSet?> generateQuestions({
    required String sourceType,
    required String sourceId,
  }) async {
    final response = await supabase.functions.invoke(
      'text-questions-generate',
      body: {
        'sourceType': sourceType,
        'sourceId': sourceId,
        'uiLanguage': 'pt',
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    final raw = Map<String, dynamic>.from(data);
    final setRaw = raw['questionSet'] is Map
        ? Map<String, dynamic>.from(raw['questionSet'] as Map)
        : raw;
    if (setRaw['text_questions'] == null && setRaw['questions'] is List) {
      setRaw['text_questions'] = setRaw['questions'];
    }
    return TextQuestionSet.fromRow(setRaw);
  }

  Future<List<Map<String, dynamic>>> fetchTtsChunks({
    required LibraryText text,
    String voiceGender = 'female',
  }) async {
    final body = <String, dynamic>{'voiceGender': voiceGender};
    switch (text.sourceKind) {
      case LibraryTextSource.temporary:
        body['temporaryTextId'] = text.id;
      case LibraryTextSource.personal:
        body['personalTextId'] = text.id;
      case LibraryTextSource.library:
        body['libraryTextId'] = text.id;
    }
    final response = await supabase.functions.invoke(
      'tts-text-plan',
      body: body,
    );
    final data = response.data;
    final chunks = data is Map ? data['chunks'] : null;
    if (chunks is! List) return const [];
    final result = chunks
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
    result.sort(
      (a, b) => ((a['idx'] as num?) ?? 0).compareTo((b['idx'] as num?) ?? 0),
    );
    return result;
  }

  Future<Map<String, String>> fetchTranslationCache({
    required LibraryText text,
    required String targetLocale,
    required List<String> segmentKeys,
  }) async {
    if (segmentKeys.isEmpty) return const {};
    final rows = text.isOwned
        ? await supabase
              .from('owned_text_translation_cache')
              .select('segment_key, source_hash, translation')
              .eq('source_type', text.sourceKind.raw)
              .eq('source_id', text.id)
              .eq('target_locale', targetLocale)
              .inFilter('segment_key', segmentKeys)
        : await supabase
              .from('text_translation_cache')
              .select('segment_key, source_hash, translation')
              .eq('text_id', text.id)
              .eq('target_locale', targetLocale)
              .inFilter('segment_key', segmentKeys);
    final result = <String, String>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final key = '${row['segment_key']}:${row['source_hash']}';
      result[key] = (row['translation'] as String? ?? '').trim();
    }
    return result;
  }

  Future<void> upsertTranslationCache({
    required LibraryText text,
    required String targetLocale,
    required String segmentKey,
    required String sourceText,
    required String sourceHash,
    required String translation,
  }) async {
    if (text.isOwned) {
      await supabase.from('owned_text_translation_cache').upsert(
        {
          'source_type': text.sourceKind.raw,
          'source_id': text.id,
          'target_locale': targetLocale,
          'segment_key': segmentKey,
          'source_text': sourceText,
          'source_hash': sourceHash,
          'translation': translation,
          'provider': 'ai',
        },
        onConflict:
            'source_type,source_id,target_locale,segment_key,source_hash',
      );
    } else {
      await supabase.from('text_translation_cache').upsert({
        'text_id': text.id,
        'target_locale': targetLocale,
        'segment_key': segmentKey,
        'source_text': sourceText,
        'source_hash': sourceHash,
        'translation': translation,
        'provider': 'ai',
      }, onConflict: 'text_id,target_locale,segment_key,source_hash');
    }
  }

  Future<String?> translateSentence({
    required String text,
    required String language,
    required String targetLocale,
  }) async {
    final chunks = chunkLongTextForTranslation(text);
    final translated = <String>[];
    for (final chunk in chunks) {
      final response = await supabase.functions.invoke(
        'vocab-enrich',
        body: {
          'surfaceTerm': chunk,
          'language': language,
          'targetTranslationLocale': targetLocale,
          'mode': 'translation_only',
          'entryKind': 'sentence',
        },
      );
      final data = response.data;
      if (data is! Map) return null;
      final primary = extractPrimaryTranslation(
        (data['translation'] as String? ?? '').trim(),
      );
      if (primary.isEmpty) return null;
      translated.add(primary);
    }
    if (translated.isEmpty) return null;
    final joined = joinTranslatedChunks(translated);
    return joined.isEmpty ? null : joined;
  }
}
