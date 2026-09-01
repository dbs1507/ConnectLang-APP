/// Porte de `buildInlineTranslationUnits` / `hashTranslationSource` /
/// `chunkLongTextForTranslation` de `StudentTextLibraryPage.tsx`.
class InlineTranslationUnit {
  const InlineTranslationUnit({
    required this.id,
    required this.text,
    required this.startsNewParagraph,
  });

  final String id;
  final String text;
  final bool startsNewParagraph;
}

String translationLocaleFromAppLanguage(String lang) {
  return lang == 'PT' ? 'pt-BR' : lang.toLowerCase();
}

String extractPrimaryTranslation(String value) {
  final parts = value
      .split(RegExp(r'\s*·\s*'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty);
  return parts.isEmpty ? '' : parts.first;
}

String hashTranslationSource(String text) {
  var hash = 2166136261;
  for (final code in text.codeUnits) {
    hash ^= code;
    hash = (hash * 16777619).toSigned(32);
  }
  return hash.toUnsigned(32).toRadixString(16);
}

List<String> splitLineIntoSentences(String line) {
  const decimalDot = '\uE000';
  final protected = line.replaceAllMapped(
    RegExp(r'(\d)\.(\d)'),
    (m) => '${m[1]}$decimalDot${m[2]}',
  );
  final matches = RegExp(
    r'''[^.!?]+(?:[.!?]+["')\]]*)?''',
  ).allMatches(protected);
  final raw = matches.isEmpty
      ? [protected]
      : matches.map((m) => m.group(0)!).toList();
  return [
    for (final sentence in raw) sentence.replaceAll(decimalDot, '.').trim(),
  ].where((s) => s.isNotEmpty).toList();
}

List<String> splitReadingParagraphs(String content) {
  return content
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

List<InlineTranslationUnit> buildInlineTranslationUnits(String content) {
  final units = <InlineTranslationUnit>[];
  final lines = content.replaceAll('\r\n', '\n').split('\n');
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    final trimmed = lines[lineIndex].trim();
    if (trimmed.isEmpty) continue;
    final sentences = splitLineIntoSentences(trimmed);
    for (
      var sentenceIndex = 0;
      sentenceIndex < sentences.length;
      sentenceIndex++
    ) {
      units.add(
        InlineTranslationUnit(
          id: '$lineIndex:$sentenceIndex',
          text: sentences[sentenceIndex],
          startsNewParagraph: sentenceIndex == 0,
        ),
      );
    }
  }
  return units;
}

List<String> chunkLongTextForTranslation(String text, {int maxChars = 88}) {
  final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return const [];
  if (normalized.length <= maxChars) return [normalized];

  final clauseSplit = normalized
      .split(RegExp(r'(?<=[,;:])\s+'))
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
  final clauseUnits = clauseSplit.length > 1 ? clauseSplit : [normalized];
  final chunks = <String>[];
  var current = '';

  void pushWordChunks(String segment) {
    final words = segment.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var carry = '';
    for (final word in words) {
      final candidate = carry.isEmpty ? word : '$carry $word';
      if (candidate.length <= maxChars) {
        carry = candidate;
      } else {
        if (carry.isNotEmpty) chunks.add(carry);
        carry = word;
      }
    }
    if (carry.isNotEmpty) chunks.add(carry);
  }

  for (final clause in clauseUnits) {
    if (clause.length > maxChars) {
      if (current.isNotEmpty) {
        chunks.add(current);
        current = '';
      }
      pushWordChunks(clause);
      continue;
    }
    final candidate = current.isEmpty ? clause : '$current $clause';
    if (candidate.length <= maxChars) {
      current = candidate;
    } else {
      if (current.isNotEmpty) chunks.add(current);
      current = clause;
    }
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

String joinTranslatedChunks(List<String> chunks) {
  return chunks
      .join(' ')
      .replaceAllMapped(RegExp(r'\s+([,.;!?])'), (m) => m[1]!)
      .trim();
}
