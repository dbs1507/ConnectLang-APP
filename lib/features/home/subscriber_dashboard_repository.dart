import '../../core/supabase_client.dart';
import '../study_coach/models/study_coach_plan.dart';
import '../study_coach/study_coach_repository.dart';
import '../vocabulary/models/vocabulary_entry.dart';

class DashboardVocabSummary {
  const DashboardVocabSummary({
    required this.total,
    required this.due,
    required this.recent,
  });

  final int total;
  final int due;
  final List<VocabularyEntry> recent;
}

class DashboardAnnouncement {
  const DashboardAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final String? authorName;
}

class DashboardOpenAssignment {
  const DashboardOpenAssignment({
    required this.id,
    required this.kind,
    required this.title,
    required this.language,
    this.cefr,
    this.focusTags = const [],
    this.targetCount,
  });

  final String id;
  final String kind;
  final String title;
  final String language;
  final String? cefr;
  final List<String> focusTags;
  final int? targetCount;

  String get label => switch (kind) {
    'vocab_review' => 'Revisar vocabulário',
    'dictation_focus' => 'Ditado focado',
    'read_text' => 'Ler texto',
    'read_questions' => 'Perguntas de leitura',
    'save_vocab_from_text' => 'Salvar vocabulário do texto',
    'production' => title.isEmpty ? 'Produção' : title,
    _ => title.isEmpty ? 'Tarefa de estudo' : title,
  };
}

class CefrBanner {
  const CefrBanner({
    required this.id,
    required this.language,
    required this.isRecalibration,
    this.fromCefr,
    this.toCefr,
    this.currentCefr,
  });

  final String id;
  final String language;
  final bool isRecalibration;
  final String? fromCefr;
  final String? toCefr;
  final String? currentCefr;

  String get message {
    final lang = taughtLanguages[language] ?? language;
    if (isRecalibration) {
      return 'Hora de recalibrar seu nível de $lang${currentCefr != null ? ' (hoje $currentCefr)' : ''}.';
    }
    if (fromCefr != null && toCefr != null) {
      return 'Você pode subir de $fromCefr para $toCefr em $lang. Faça um nivelamento pra confirmar.';
    }
    return 'Há uma sugestão de nivelamento em $lang.';
  }
}

class SubscriberDashboardData {
  const SubscriberDashboardData({
    required this.vocab,
    required this.announcements,
    required this.unreviewedAiNotes,
    required this.plan,
    required this.openAssignments,
    required this.cefrBanner,
  });

  final DashboardVocabSummary vocab;
  final List<DashboardAnnouncement> announcements;
  final int unreviewedAiNotes;
  final StudyCoachPlan? plan;
  final List<DashboardOpenAssignment> openAssignments;
  final CefrBanner? cefrBanner;
}

class SubscriberDashboardRepository {
  const SubscriberDashboardRepository(this._userId);

  final String _userId;
  final _coach = const StudyCoachRepository();

  Future<SubscriberDashboardData> fetch({
    required String? studyLanguage,
  }) async {
    final vocabRows = await supabase
        .from('student_vocabulary')
        .select(
          'id, term, translation, description, context, example, part_of_speech, language, '
          'created_at, next_review_at, interval_minutes, last_rating, srs_difficulty, saved_from_base_vocab_id',
        )
        .eq('student_id', _userId)
        .isFilter('teacher_vocab_id', null)
        .isFilter('archived_at', null)
        .order('created_at', ascending: false);

    final entries = (vocabRows as List)
        .cast<Map<String, dynamic>>()
        .map(VocabularyEntry.fromRow)
        .toList();
    final due = entries.where((e) => e.isDue).length;

    final announcementRows = await supabase
        .from('announcements')
        .select('id, title, content, author_id, created_at')
        .eq('target_type', 'direct')
        .eq('target_student_id', _userId)
        .order('created_at', ascending: false)
        .limit(8);

    final announcementsRaw = (announcementRows as List)
        .cast<Map<String, dynamic>>();
    final authorIds = announcementsRaw
        .map((r) => r['author_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final authorsById = <String, String>{};
    if (authorIds.isNotEmpty) {
      final authors = await supabase
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', authorIds);
      for (final row in (authors as List).cast<Map<String, dynamic>>()) {
        authorsById[row['id'] as String] = (row['full_name'] as String?) ?? '';
      }
    }

    final aiRows = await supabase
        .from('student_notebook_entries')
        .select('id')
        .eq('student_id', _userId)
        .eq('entry_kind', 'ai_explanation')
        .isFilter('reviewed_at', null);

    StudyCoachPlan? plan;
    var openAssignments = const <DashboardOpenAssignment>[];
    CefrBanner? banner;
    if (studyLanguage != null) {
      plan = await _coach.fetchCachedPlan(studyLanguage);
      final assignmentRows = await supabase
          .from('subscriber_study_assignments')
          .select('id, language, kind, status, payload')
          .eq('language', studyLanguage)
          .inFilter('status', ['assigned', 'in_progress'])
          .order('due_at', ascending: true);
      openAssignments = [
        for (final row in (assignmentRows as List).cast<Map<String, dynamic>>())
          () {
            final payload = row['payload'] is Map
                ? Map<String, dynamic>.from(row['payload'] as Map)
                : <String, dynamic>{};
            final rawTags = payload['focusTags'] ?? payload['focus_tags'];
            return DashboardOpenAssignment(
              id: row['id'] as String,
              kind: row['kind'] as String? ?? '',
              language: (row['language'] as String? ?? studyLanguage)
                  .toUpperCase(),
              title: (payload['title'] as String? ?? '').trim(),
              cefr:
                  (payload['cefr'] as String? ??
                          payload['targetCefr'] as String? ??
                          payload['target_cefr'] as String?)
                      ?.toString()
                      .toUpperCase(),
              focusTags: rawTags is List
                  ? rawTags
                        .map((t) => t.toString())
                        .where((t) => t.isNotEmpty)
                        .toList()
                  : const [],
              targetCount:
                  (payload['targetCount'] as num?)?.toInt() ??
                  (payload['target_count'] as num?)?.toInt(),
            );
          }(),
      ];
      banner = await _fetchBanner(studyLanguage);
    }

    return SubscriberDashboardData(
      vocab: DashboardVocabSummary(
        total: entries.length,
        due: due,
        recent: entries.take(5).toList(),
      ),
      announcements: [
        for (final row in announcementsRaw)
          DashboardAnnouncement(
            id: row['id'] as String,
            title: row['title'] as String? ?? '',
            content: row['content'] as String? ?? '',
            createdAt:
                DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.now(),
            authorName: authorsById[row['author_id'] as String?],
          ),
      ],
      unreviewedAiNotes: (aiRows as List).length,
      plan: plan,
      openAssignments: openAssignments,
      cefrBanner: banner,
    );
  }

  Future<CefrBanner?> _fetchBanner(String language) async {
    final recal = await supabase
        .from('cefr_recalibration_suggestions')
        .select('id, language, current_cefr, status')
        .eq('language', language)
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (recal != null) {
      return CefrBanner(
        id: recal['id'] as String,
        language: language,
        isRecalibration: true,
        currentCefr: recal['current_cefr'] as String?,
      );
    }
    final promo = await supabase
        .from('cefr_promotion_suggestions')
        .select('id, language, from_cefr, suggested_cefr, status')
        .eq('language', language)
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (promo != null) {
      return CefrBanner(
        id: promo['id'] as String,
        language: language,
        isRecalibration: false,
        fromCefr: promo['from_cefr'] as String?,
        toCefr: promo['suggested_cefr'] as String?,
      );
    }
    return null;
  }

  Future<void> dismissBanner(CefrBanner banner) async {
    if (banner.isRecalibration) {
      await supabase.rpc(
        'cefr_recalibration_dismiss',
        params: {'p_language': banner.language, 'p_suggestion_id': banner.id},
      );
    } else {
      await supabase.rpc(
        'cefr_suggestion_dismiss',
        params: {'p_language': banner.language, 'p_suggestion_id': banner.id},
      );
    }
  }
}
