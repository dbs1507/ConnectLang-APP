import '../../core/supabase_client.dart';

/// Porta `syncStudyAssignmentCompletion` / `completeDictationFocusStudyAssignments`
/// / `completeLibraryStudyAssignments` de `src/lib/studyAssignments.ts`.
class StudyAssignmentsRepository {
  const StudyAssignmentsRepository();

  Future<void> syncQuiet(String? language) async {
    if (language == null || language.isEmpty) return;
    try {
      await supabase.rpc(
        'assignment_sync_completion',
        params: {'p_language': language},
      );
    } catch (_) {}
  }

  Future<void> completeDictationFocus({
    required String language,
    required List<String> focusTags,
    required int completedCount,
  }) async {
    await syncQuiet(language);
    if (completedCount < 3) return;

    final sessionTags = focusTags
        .map((t) => t.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_'))
        .where((t) => t.isNotEmpty)
        .toList();
    try {
      final openRows = await supabase
          .from('subscriber_study_assignments')
          .select('id, kind, payload, status')
          .eq('language', language)
          .eq('kind', 'dictation_focus')
          .inFilter('status', ['assigned', 'in_progress']);
      final matchingIds = <String>[];
      for (final row in (openRows as List).cast<Map<String, dynamic>>()) {
        final payload = row['payload'] is Map
            ? Map<String, dynamic>.from(row['payload'] as Map)
            : <String, dynamic>{};
        final target =
            (payload['targetCount'] as num?)?.toInt() ??
            (payload['target_count'] as num?)?.toInt() ??
            5;
        final need = target.clamp(3, 12);
        if (completedCount < need) continue;
        final rawTags = payload['focusTags'] ?? payload['focus_tags'];
        final tags = rawTags is List
            ? rawTags
                  .map(
                    (t) => t.toString().trim().toLowerCase().replaceAll(
                      RegExp(r'[\s-]+'),
                      '_',
                    ),
                  )
                  .where((t) => t.isNotEmpty)
                  .toList()
            : const <String>[];
        if (sessionTags.isEmpty ||
            tags.isEmpty ||
            (tags.length == 1 && tags.first == 'other') ||
            tags.any(sessionTags.contains)) {
          matchingIds.add(row['id'] as String);
        }
      }
      if (matchingIds.isEmpty) return;
      final now = DateTime.now().toUtc().toIso8601String();
      await supabase
          .from('subscriber_study_assignments')
          .update({
            'status': 'done',
            'completed_at': now,
            'result_meta': {
              'signal': 'client_dictation_session_complete',
              'completedCount': completedCount,
              'focusTags': sessionTags,
              'completedAt': now,
            },
          })
          .inFilter('id', matchingIds);
    } catch (_) {}
  }

  Future<void> completeLibrary({
    required String language,
    required String textId,
    required List<String> kinds,
  }) async {
    await syncQuiet(language);
    try {
      final openRows = await supabase
          .from('subscriber_study_assignments')
          .select('id, kind, payload, status')
          .eq('language', language)
          .inFilter('status', ['assigned', 'in_progress'])
          .inFilter('kind', kinds);
      final matchingIds = <String>[];
      for (final row in (openRows as List).cast<Map<String, dynamic>>()) {
        final payload = row['payload'] is Map
            ? Map<String, dynamic>.from(row['payload'] as Map)
            : <String, dynamic>{};
        final rowTextId =
            (payload['textId'] as String? ??
                    payload['text_id'] as String? ??
                    '')
                .trim();
        if (rowTextId == textId && kinds.contains(row['kind'])) {
          matchingIds.add(row['id'] as String);
        }
      }
      if (matchingIds.isEmpty) return;
      final now = DateTime.now().toUtc().toIso8601String();
      await supabase
          .from('subscriber_study_assignments')
          .update({
            'status': 'done',
            'completed_at': now,
            'result_meta': {
              'signal': 'client_library_complete',
              'textId': textId,
              'kinds': kinds,
              'completedAt': now,
            },
          })
          .inFilter('id', matchingIds);
    } catch (_) {}
  }
}
