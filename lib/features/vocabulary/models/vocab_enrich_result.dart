/// Porte de `VocabEnrichResult`/`buildEnrichedTranslationField` de
/// `src/lib/vocabEnrich.ts` — só o modo "full" pra uma palavra isolada
/// (`entryKind: 'word'`); frases (`entry_kind='sentence'`) ficam de fora
/// desta fatia, igual ao restante do Vocabulário.
const int _maxCombinedTranslation = 320;
const int _maxFlashcardTranslationGlosses = 2;

/// Junta `translation` (pode já vir com "·" da API) com `translationAlternates`,
/// sem duplicar — mesmo limite/formatação do web.
String buildEnrichedTranslationField(String translation, List<String>? alternates) {
  final fromMain = translation.split(RegExp(r'\s*·\s*')).map((s) => s.trim()).where((s) => s.isNotEmpty);
  final fromAlts = (alternates ?? []).map((s) => s.trim()).where((s) => s.isNotEmpty);
  final seen = <String>{};
  final parts = <String>[];
  for (final part in [...fromMain, ...fromAlts]) {
    if (parts.length >= _maxFlashcardTranslationGlosses) break;
    final key = part.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    parts.add(part);
  }
  var out = parts.join(' · ');
  if (out.length > _maxCombinedTranslation) {
    out = '${out.substring(0, _maxCombinedTranslation - 1).trimRight()}…';
  }
  return out;
}

class VocabEnrichResult {
  const VocabEnrichResult({
    required this.translation,
    required this.example,
    required this.context,
    required this.description,
    required this.partOfSpeech,
  });

  final String translation;
  final String example;
  final String context;
  final String description;
  final String? partOfSpeech;

  factory VocabEnrichResult.fromRow(Map<String, dynamic> row) {
    final translationRaw = (row['translation'] as String? ?? '').trim();
    final rawAlts = row['translationAlternates'] ?? row['translation_alternates'];
    final alternates = rawAlts is List ? rawAlts.map((e) => e.toString()).toList() : null;
    return VocabEnrichResult(
      translation: buildEnrichedTranslationField(translationRaw, alternates),
      example: (row['example'] as String? ?? '').trim(),
      context: (row['context'] as String? ?? '').trim(),
      description: (row['description'] as String? ?? '').trim(),
      partOfSpeech: (row['partOfSpeech'] as String?)?.trim(),
    );
  }
}
