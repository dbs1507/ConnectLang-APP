import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'models/srs_rating.dart';
import 'models/srs_schedule.dart';
import 'models/vocab_enrich_result.dart';
import 'models/vocabulary_entry.dart';

const _mineColumns =
    'id, term, translation, description, context, example, part_of_speech, language, '
    'student_id, created_at, next_review_at, interval_minutes, last_rating, srs_difficulty';

class DuplicateVocabularyTermException implements Exception {
  const DuplicateVocabularyTermException();
}

String _normalizeTerm(String term) => term.trim().toLowerCase();

/// Só a fatia "Minhas palavras" de `student_vocabulary` (ver
/// docs/planejamento.md item 2). Espelha as queries de
/// `src/pages/student/VocabularyPage.tsx` (`loadMine`, `confirmDeleteWord`,
/// `persistSrsReview`), sem categorias/base/professor/IA ainda.
class VocabularyRepository {
  const VocabularyRepository(this._studentId);

  final String _studentId;

  Future<List<VocabularyEntry>> fetchMine() async {
    final rows = await supabase
        .from('student_vocabulary')
        .select(_mineColumns)
        .eq('student_id', _studentId)
        .isFilter('teacher_vocab_id', null)
        .isFilter('archived_at', null)
        .order('created_at', ascending: false);
    return (rows as List).map((row) => VocabularyEntry.fromRow(row as Map<String, dynamic>)).toList();
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
      if (_normalizeTerm(row['term'] as String) == norm) return row['id'] as String;
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
            'description': description?.trim().isNotEmpty == true ? description!.trim() : null,
            'context': context?.trim().isNotEmpty == true ? context!.trim() : null,
            'example': example?.trim().isNotEmpty == true ? example!.trim() : null,
            'part_of_speech': partOfSpeech?.trim().isNotEmpty == true ? partOfSpeech!.trim() : null,
            'language': language,
            'source': 'student',
            'entry_kind': 'word',
            'next_review_at': DateTime.now().toUtc().toIso8601String(),
            'interval_minutes': 0,
            'archived_at': null,
          })
          .select(_mineColumns)
          .single();
      return VocabularyEntry.fromRow(row);
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
    final nextReviewAt = DateTime.now().toUtc().add(Duration(minutes: schedule.nextIntervalMinutes));

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
  Future<VocabEnrichResult?> enrichTerm({required String term, required String language}) async {
    final response = await supabase.functions.invoke(
      'vocab-enrich',
      body: {
        'surfaceTerm': term.trim(),
        'language': language,
        'targetTranslationLocale': 'pt-BR',
        'entryKind': 'word',
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    return VocabEnrichResult.fromRow(Map<String, dynamic>.from(data));
  }

  /// "Tirar da lista" — arquivamento suave (`archived_at`), igual ao web;
  /// a aba de arquivados fica para uma próxima fatia.
  Future<void> archive(String entryId) async {
    await supabase
        .from('student_vocabulary')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', entryId)
        .eq('student_id', _studentId)
        .isFilter('archived_at', null);
  }
}
