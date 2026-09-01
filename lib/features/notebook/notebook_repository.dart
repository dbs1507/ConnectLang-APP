import '../../core/supabase_client.dart';
import 'models/notebook_entry.dart';

const _entryColumns =
    'id, content, language, link_type, link_id, link_label, entry_kind, title, reviewed_at, created_at, updated_at';

/// Espelha `src/lib/notebook.ts` no web — só o CRUD manual
/// (`student_notebook_entries`). Vínculo com atividade/texto/aula fica pra
/// quando essas features existirem no app; vínculo com vocabulário já
/// funciona (reaproveita `VocabularyRepository.fetchMine()` no picker).
class NotebookRepository {
  const NotebookRepository(this._studentId);

  final String _studentId;

  Future<List<NotebookEntry>> fetchAll() async {
    final rows = await supabase
        .from('student_notebook_entries')
        .select(_entryColumns)
        .eq('student_id', _studentId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((row) => NotebookEntry.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<NotebookEntry> create({
    required String content,
    required String language,
    NotebookLinkType? linkType,
    String? linkId,
    String? linkLabel,
  }) async {
    final row = await supabase
        .from('student_notebook_entries')
        .insert({
          'student_id': _studentId,
          'content': content.trim(),
          'language': language,
          'link_type': linkType?.raw,
          'link_id': linkId,
          'link_label': linkLabel,
          'entry_kind': 'manual',
          'is_plan_scratchpad': false,
        })
        .select(_entryColumns)
        .single();
    return NotebookEntry.fromRow(row);
  }

  Future<NotebookEntry> update({
    required String entryId,
    required String content,
    required String language,
    NotebookLinkType? linkType,
    String? linkId,
    String? linkLabel,
  }) async {
    final row = await supabase
        .from('student_notebook_entries')
        .update({
          'content': content.trim(),
          'language': language,
          'link_type': linkType?.raw,
          'link_id': linkId,
          'link_label': linkLabel,
        })
        .eq('id', entryId)
        .eq('student_id', _studentId)
        .select(_entryColumns)
        .single();
    return NotebookEntry.fromRow(row);
  }

  Future<void> delete(String entryId) async {
    await supabase
        .from('student_notebook_entries')
        .delete()
        .eq('id', entryId)
        .eq('student_id', _studentId);
  }

  Future<NotebookEntry> createAiExplanation({
    required String content,
    required String language,
    required String title,
    required String aiSource,
    NotebookLinkType? linkType,
    String? linkId,
    String? linkLabel,
  }) async {
    final row = await supabase
        .from('student_notebook_entries')
        .insert({
          'student_id': _studentId,
          'content': content.trim(),
          'language': language,
          'link_type': linkType?.raw,
          'link_id': linkId,
          'link_label': linkLabel,
          'entry_kind': 'ai_explanation',
          'ai_source': aiSource,
          'title': title,
          'is_plan_scratchpad': false,
        })
        .select(_entryColumns)
        .single();
    return NotebookEntry.fromRow(row);
  }

  Future<int> countUnreviewedAi() async {
    final rows = await supabase
        .from('student_notebook_entries')
        .select('id')
        .eq('student_id', _studentId)
        .eq('entry_kind', 'ai_explanation')
        .isFilter('reviewed_at', null);
    return (rows as List).length;
  }

  Future<NotebookEntry> markReviewed(
    String entryId, {
    required bool reviewed,
  }) async {
    final row = await supabase
        .from('student_notebook_entries')
        .update({
          'reviewed_at': reviewed
              ? DateTime.now().toUtc().toIso8601String()
              : null,
        })
        .eq('id', entryId)
        .eq('student_id', _studentId)
        .select(_entryColumns)
        .single();
    return NotebookEntry.fromRow(row);
  }
}
