/// Espelha `vocab_categories` — catálogo global (não por aluno), lido só
/// leitura pelo app: criar/renomear/apagar categoria é ferramenta do
/// professor no web (`vocabContentCategories.ts`, `TeacherVocabularyPage.tsx`),
/// fora do escopo do app mobile. O vínculo palavra↔categoria é N:N via
/// `student_vocabulary_categories` — uma palavra pode ter várias categorias.
class VocabCategory {
  const VocabCategory({required this.id, required this.name});

  final String id;
  final String name;

  factory VocabCategory.fromRow(Map<String, dynamic> row) {
    return VocabCategory(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
    );
  }
}
