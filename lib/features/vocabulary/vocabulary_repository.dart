import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'models/base_vocabulary_entry.dart';
import 'models/srs_rating.dart';
import 'models/srs_schedule.dart';
import 'models/vocab_category.dart';
import 'models/vocab_enrich_result.dart';
import 'models/vocab_explain_result.dart';
import 'models/vocabulary_entry.dart';

const _mineColumns =
    'id, term, translation, description, context, example, part_of_speech, language, '
    'student_id, created_at, next_review_at, interval_minutes, last_rating, srs_difficulty, '
    'saved_from_base_vocab_id, entry_kind';

class DuplicateVocabularyTermException implements Exception {
  const DuplicateVocabularyTermException();
}

String _normalizeTerm(String term) => term.trim().toLowerCase();

/// Fatia do assinante em `VocabularyPage.tsx`: minhas palavras, categorias,
/// arquivados, vocabulário base e explicar/enrich por IA. Palavras do
/// professor e `entry_kind='sentence'` ficam fora.
class VocabularyRepository {
  const VocabularyRepository(this._studentId);

  final String _studentId;

  Future<List<VocabularyEntry>> fetchMine() =>
      _fetchStudentWords(archived: false);

  Future<List<VocabularyEntry>> fetchArchived() =>
      _fetchStudentWords(archived: true);

  Future<List<VocabularyEntry>> _fetchStudentWords({
    required bool archived,
  }) async {
    var query = supabase
        .from('student_vocabulary')
        .select(_mineColumns)
        .eq('student_id', _studentId)
        .isFilter('teacher_vocab_id', null);
    query = archived
        ? query.not('archived_at', 'is', null).eq('skip_archived_tab', false)
        : query.isFilter('archived_at', null);
    final rows = await query.order('created_at', ascending: false);
    final wordRows = (rows as List).cast<Map<String, dynamic>>();
    if (wordRows.isEmpty) return const [];

    final wordIds = wordRows.map((row) => row['id'] as String).toList();
    final categoryIdsByWordId = await _fetchCategoryLinks(wordIds);
    return [
      for (final row in wordRows)
        VocabularyEntry.fromRow(
          row,
          categoryIds: categoryIdsByWordId[row['id']] ?? const [],
        ),
    ];
  }

  Future<Map<String, List<String>>> _fetchCategoryLinks(
    List<String> wordIds,
  ) async {
    final rows = await supabase
        .from('student_vocabulary_categories')
        .select('student_vocab_id, category_id')
        .inFilter('student_vocab_id', wordIds);
    final result = <String, List<String>>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final wordId = row['student_vocab_id'] as String;
      (result[wordId] ??= []).add(row['category_id'] as String);
    }
    return result;
  }

  /// Catálogo global de categorias (`vocab_categories`) — só leitura pro
  /// app: criar/renomear/apagar é ferramenta do professor no web.
  Future<List<VocabCategory>> fetchCategories() async {
    final rows = await supabase
        .from('vocab_categories')
        .select('id, name')
        .order('name');
    return (rows as List)
        .map((row) => VocabCategory.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Não deixa uma falha aqui derrubar a palavra que já foi salva — o
  /// vínculo com categoria é um extra, não o dado principal. Retorna se
  /// conseguiu vincular, pra `addWord` refletir o que realmente persistiu.
  Future<bool> _setWordCategories(
    String wordId,
    List<String> categoryIds,
  ) async {
    if (categoryIds.isEmpty) return true;
    try {
      await supabase.from('student_vocabulary_categories').insert([
        for (final categoryId in categoryIds)
          {'student_vocab_id': wordId, 'category_id': categoryId},
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _findDuplicateId(String term, String language) async {
    final norm = _normalizeTerm(term);
    if (norm.isEmpty) return null;
    final rows = await supabase
        .from('student_vocabulary')
        .select('id, term')
        .eq('student_id', _studentId)
        .eq('language', language)
        .isFilter('archived_at', null);
    for (final row in rows as List) {
      if (_normalizeTerm(row['term'] as String) == norm) {
        return row['id'] as String;
      }
    }
    return null;
  }

  Future<VocabularyEntry> addWord({
    required String term,
    required String translation,
    required String language,
    String? description,
    String? context,
    String? example,
    String? partOfSpeech,
    List<String> categoryIds = const [],
    VocabEntryKind entryKind = VocabEntryKind.word,
  }) async {
    final termTrimmed = term.trim();
    final translationTrimmed = translation.trim();

    if (await _findDuplicateId(termTrimmed, language) != null) {
      throw const DuplicateVocabularyTermException();
    }

    try {
      final row = await supabase
          .from('student_vocabulary')
          .insert({
            'student_id': _studentId,
            'term': termTrimmed,
            'translation': translationTrimmed,
            'description': description?.trim().isNotEmpty == true
                ? description!.trim()
                : null,
            'context': context?.trim().isNotEmpty == true
                ? context!.trim()
                : null,
            'example': example?.trim().isNotEmpty == true
                ? example!.trim()
                : null,
            'part_of_speech': partOfSpeech?.trim().isNotEmpty == true
                ? partOfSpeech!.trim()
                : null,
            'language': language,
            'source': 'student',
            'entry_kind': entryKind.raw,
            'next_review_at': DateTime.now().toUtc().toIso8601String(),
            'interval_minutes': 0,
            'archived_at': null,
          })
          .select(_mineColumns)
          .single();
      final wordId = row['id'] as String;
      final linked = await _setWordCategories(wordId, categoryIds);
      return VocabularyEntry.fromRow(
        row,
        categoryIds: linked ? categoryIds : const [],
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const DuplicateVocabularyTermException();
      rethrow;
    }
  }

  Future<VocabularyEntry> rate(VocabularyEntry entry, SrsRating rating) async {
    final schedule = getAdaptiveSrsSchedule(
      rating: rating,
      currentDifficulty: entry.srsDifficulty,
    );
    final nextReviewAt = DateTime.now().toUtc().add(
      Duration(minutes: schedule.nextIntervalMinutes),
    );

    await supabase
        .from('student_vocabulary')
        .update({
          'last_rating': rating.name,
          'interval_minutes': schedule.nextIntervalMinutes,
          'next_review_at': nextReviewAt.toIso8601String(),
          'srs_difficulty': schedule.nextDifficulty,
        })
        .eq('id', entry.id)
        .eq('student_id', _studentId)
        .isFilter('archived_at', null);

    return entry.copyWithReview(
      rating: rating,
      nextIntervalMinutes: schedule.nextIntervalMinutes,
      nextDifficulty: schedule.nextDifficulty,
      nextReviewAt: nextReviewAt,
    );
  }

  /// Chama a edge function `vocab-enrich` (IA) — mesma function do web,
  /// só o modo "full" pra palavra isolada (`entryKind: 'word'`).
  Future<VocabEnrichResult?> enrichTerm({
    required String term,
    required String language,
    VocabEntryKind entryKind = VocabEntryKind.word,
    String? surroundingText,
    String targetTranslationLocale = 'pt-BR',
    String mode = 'full',
  }) async {
    final response = await supabase.functions.invoke(
      'vocab-enrich',
      body: {
        'surfaceTerm': term.trim(),
        'language': language,
        'targetTranslationLocale': targetTranslationLocale,
        'entryKind': entryKind.raw,
        'mode': mode,
        if (surroundingText != null && surroundingText.trim().isNotEmpty)
          'surroundingText': surroundingText.trim(),
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    final row = Map<String, dynamic>.from(data);
    if (entryKind == VocabEntryKind.sentence) {
      return VocabEnrichResult(
        translation: (row['translation'] as String? ?? '').trim(),
        example: (row['example'] as String? ?? '').trim(),
        context: (row['context'] as String? ?? '').trim(),
        description: (row['description'] as String? ?? '').trim(),
        partOfSpeech: (row['partOfSpeech'] as String?)?.trim(),
      );
    }
    return VocabEnrichResult.fromRow(row);
  }

  Future<VocabularyEntry> addFromText({
    required String term,
    required String translation,
    required String language,
    required String source,
    required String context,
    required String description,
    required VocabEntryKind entryKind,
    String? example,
    String? partOfSpeech,
    String? captureSurface,
    String? libraryTextId,
    String? temporaryTextId,
    String? personalTextId,
    List<String> categoryIds = const [],
  }) async {
    if (await _findDuplicateId(term, language) != null) {
      throw const DuplicateVocabularyTermException();
    }
    try {
      final row = await supabase
          .from('student_vocabulary')
          .insert({
            'student_id': _studentId,
            'term': term.trim(),
            'translation': translation.trim(),
            'description': description.trim(),
            'context': context.trim(),
            'example': example?.trim().isNotEmpty == true
                ? example!.trim()
                : null,
            'part_of_speech': partOfSpeech?.trim().isNotEmpty == true
                ? partOfSpeech!.trim()
                : null,
            'capture_surface': captureSurface?.trim(),
            'language': language,
            'source': source,
            'entry_kind': entryKind.raw,
            'library_text_id': libraryTextId,
            'temporary_text_id': temporaryTextId,
            'personal_text_id': personalTextId,
            'next_review_at': DateTime.now().toUtc().toIso8601String(),
            'interval_minutes': 0,
            'archived_at': null,
          })
          .select(_mineColumns)
          .single();
      final wordId = row['id'] as String;
      final linked = await _setWordCategories(wordId, categoryIds);
      return VocabularyEntry.fromRow(
        row,
        categoryIds: linked ? categoryIds : const [],
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const DuplicateVocabularyTermException();
      rethrow;
    }
  }

  /// "Tirar da lista" — arquivamento suave (`archived_at`), igual ao web.
  Future<void> archive(String entryId) async {
    await supabase
        .from('student_vocabulary')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', entryId)
        .eq('student_id', _studentId)
        .isFilter('archived_at', null);
  }

  Future<void> restore(String entryId) async {
    await supabase
        .from('student_vocabulary')
        .update({'archived_at': null})
        .eq('id', entryId)
        .eq('student_id', _studentId)
        .not('archived_at', 'is', null);
  }

  /// Catálogo `base_vocabulary` filtrado por idioma (no web a lista inteira
  /// vem paginada e o filtro é no cliente; no app o filtro no servidor evita
  /// baixar milhares de linhas de outros idiomas).
  Future<List<BaseVocabularyEntry>> fetchBase({
    required String language,
  }) async {
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await supabase
          .from('base_vocabulary')
          .select('id, term, translation, example, description, language, cefr')
          .eq('language', language)
          .order('term')
          .range(from, from + pageSize - 1);
      final chunk = (page as List).cast<Map<String, dynamic>>();
      rows.addAll(chunk);
      if (chunk.length < pageSize) break;
      from += pageSize;
    }
    if (rows.isEmpty) return const [];

    final ids = rows.map((row) => row['id'] as String).toList();
    final categoryIdsByWordId = <String, List<String>>{};
    const linkPage = 500;
    for (var i = 0; i < ids.length; i += linkPage) {
      final slice = ids.sublist(
        i,
        i + linkPage > ids.length ? ids.length : i + linkPage,
      );
      final links = await supabase
          .from('base_vocabulary_categories')
          .select('base_vocab_id, category_id')
          .inFilter('base_vocab_id', slice);
      for (final row in (links as List).cast<Map<String, dynamic>>()) {
        final wordId = row['base_vocab_id'] as String;
        (categoryIdsByWordId[wordId] ??= []).add(row['category_id'] as String);
      }
    }

    return [
      for (final row in rows)
        BaseVocabularyEntry.fromRow(
          row,
          categoryIds: categoryIdsByWordId[row['id']] ?? const [],
        ),
    ];
  }

  Future<VocabularyEntry> addFromBase(BaseVocabularyEntry base) async {
    if (await _findDuplicateId(base.term, base.language) != null) {
      throw const DuplicateVocabularyTermException();
    }
    try {
      final row = await supabase
          .from('student_vocabulary')
          .insert({
            'student_id': _studentId,
            'term': base.term.trim(),
            'translation': base.translation.trim(),
            'description': (base.description ?? base.translation).trim(),
            'context': (base.example ?? '').trim().isEmpty
                ? 'Nível ${base.cefr}'
                : base.example!.trim(),
            'example': (base.example ?? '').trim().isEmpty
                ? null
                : base.example!.trim(),
            'language': base.language,
            'source': 'student',
            'entry_kind': 'word',
            'cefr': base.cefr.isEmpty ? null : base.cefr,
            'next_review_at': DateTime.now().toUtc().toIso8601String(),
            'interval_minutes': 0,
            'archived_at': null,
            'saved_from_base_vocab_id': base.id,
          })
          .select(_mineColumns)
          .single();
      final wordId = row['id'] as String;
      final linked = await _setWordCategories(wordId, base.categoryIds);
      return VocabularyEntry.fromRow(
        row,
        categoryIds: linked ? base.categoryIds : const [],
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const DuplicateVocabularyTermException();
      rethrow;
    }
  }

  /// Edge function `vocab-explain` — mesma do web, sempre em português.
  Future<VocabExplainResult?> explainTerm({
    required String term,
    required String language,
    String? translation,
    String? example,
    String? context,
    String? description,
  }) async {
    final response = await supabase.functions.invoke(
      'vocab-explain',
      body: {
        'term': term.trim(),
        'language': language,
        'uiLanguage': 'pt',
        if (translation != null && translation.trim().isNotEmpty)
          'translation': translation.trim(),
        if (example != null && example.trim().isNotEmpty)
          'example': example.trim(),
        if (context != null && context.trim().isNotEmpty)
          'context': context.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    return VocabExplainResult.fromRow(Map<String, dynamic>.from(data));
  }

  Future<String?> fetchTtsUrl({
    required String text,
    required String language,
    String voiceGender = 'female',
  }) async {
    final response = await supabase.functions.invoke(
      'tts-generate',
      body: {
        'text': text,
        'language': language,
        'origin': 'mine',
        'voiceGender': voiceGender,
        'delivery': 'url',
      },
    );
    final data = response.data;
    if (data is Map && data['audioUrl'] is String) {
      return data['audioUrl'] as String;
    }
    return null;
  }
}
