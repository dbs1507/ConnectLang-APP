import '../../core/supabase_client.dart';
import 'models/library_text.dart';

const _textColumns = 'id, title, content, language, cefr, tags, created_at';

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
}
