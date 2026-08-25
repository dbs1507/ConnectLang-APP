/// Recorte de `dictation_items` usado nesta fatia: só o pool público de
/// prática livre (`is_free_practice = true`). Itens de atividade de
/// professor, nivelamento calibrado por IA e tags de reforço ficam de fora.
class DictationItem {
  const DictationItem({
    required this.id,
    required this.promptText,
    required this.language,
    this.promptTranslation,
    this.cefr,
  });

  final String id;
  final String promptText;
  final String? promptTranslation;
  final String language;
  final String? cefr;

  factory DictationItem.fromRow(Map<String, dynamic> row) {
    return DictationItem(
      id: row['id'] as String,
      promptText: row['prompt_text'] as String? ?? '',
      promptTranslation: row['prompt_translation'] as String?,
      language: row['language'] as String,
      cefr: row['cefr'] as String?,
    );
  }
}
