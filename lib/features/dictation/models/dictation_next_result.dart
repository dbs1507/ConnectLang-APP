class DictationNextResult {
  const DictationNextResult({
    required this.mode,
    required this.headline,
    required this.itemIds,
    this.focusTag,
    this.message,
    this.source,
  });

  final String mode;
  final String headline;
  final List<String> itemIds;
  final String? focusTag;
  final String? message;
  final String? source;

  static DictationNextResult? fromRow(Map<String, dynamic> row) {
    final rawIds = row['itemIds'] ?? row['item_ids'];
    final itemIds = rawIds is List
        ? rawIds.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    return DictationNextResult(
      mode: (row['mode'] as String? ?? '').trim(),
      headline: (row['headline'] as String? ?? '').trim(),
      itemIds: itemIds,
      focusTag: (row['focusTag'] as String? ?? row['focus_tag'] as String?)
          ?.trim(),
      message: (row['message'] as String?)?.trim(),
      source: (row['source'] as String?)?.trim(),
    );
  }
}

class DictationReinforceDrill {
  const DictationReinforceDrill({
    required this.focus,
    required this.example,
    required this.prompt,
    required this.hint,
    required this.expected,
  });

  final String focus;
  final String example;
  final String prompt;
  final String hint;
  final String expected;

  factory DictationReinforceDrill.fromRow(Map<String, dynamic> row) {
    return DictationReinforceDrill(
      focus: (row['focus'] as String? ?? '').trim(),
      example: (row['example'] as String? ?? '').trim(),
      prompt: (row['prompt'] as String? ?? '').trim(),
      hint: (row['hint'] as String? ?? '').trim(),
      expected: (row['expected'] as String? ?? '').trim(),
    );
  }
}

class DictationReinforceResult {
  const DictationReinforceResult({
    required this.headline,
    required this.explanation,
    required this.rule,
    required this.drills,
    required this.source,
  });

  final String headline;
  final String explanation;
  final String rule;
  final List<DictationReinforceDrill> drills;
  final String source;

  DictationReinforceDrill? get firstDrill =>
      drills.isEmpty ? null : drills.first;

  String notebookTitle() =>
      headline.length > 120 ? '${headline.substring(0, 120)}…' : headline;

  String notebookContent() {
    final drill = firstDrill;
    return [
      explanation,
      if (rule.isNotEmpty) 'Regra: $rule',
      if (drill != null) ...[
        if (drill.example.isNotEmpty) 'Exemplo: ${drill.example}',
        if (drill.focus.isNotEmpty) 'Foco: ${drill.focus}',
        if (drill.prompt.isNotEmpty) 'Complete: ${drill.prompt}',
        if (drill.hint.isNotEmpty) 'Dica: ${drill.hint}',
        if (drill.expected.isNotEmpty) 'Resposta: ${drill.expected}',
      ],
    ].join('\n\n');
  }

  static DictationReinforceResult? fromRow(Map<String, dynamic> row) {
    final explanation = (row['explanation'] as String? ?? '').trim();
    if (explanation.isEmpty) return null;
    final rawDrills = row['drills'];
    final drills = <DictationReinforceDrill>[];
    if (rawDrills is List) {
      drills.addAll(
        rawDrills.whereType<Map>().map(
          (d) => DictationReinforceDrill.fromRow(Map<String, dynamic>.from(d)),
        ),
      );
    } else if (row['drill'] is Map) {
      drills.add(
        DictationReinforceDrill.fromRow(
          Map<String, dynamic>.from(row['drill'] as Map),
        ),
      );
    }
    return DictationReinforceResult(
      headline: (row['headline'] as String? ?? '').trim(),
      explanation: explanation,
      rule: (row['rule'] as String? ?? '').trim(),
      drills: drills,
      source: row['source'] == 'fallback' ? 'fallback' : 'ai',
    );
  }
}

class DictationLaunchArgs {
  const DictationLaunchArgs({
    required this.language,
    this.cefr,
    this.focusTags = const [],
    this.sessionSize = 10,
    this.autoStartCalibrated = false,
  });

  final String language;
  final String? cefr;
  final List<String> focusTags;
  final int sessionSize;
  final bool autoStartCalibrated;

  static const _aliases = {
    'ommission': 'omission',
    'tense': 'verb_tense',
    'wordorder': 'word_order',
  };

  static const allowedTags = {
    'articles',
    'verb_tense',
    'spelling',
    'word_order',
    'omission',
    'addition',
    'prepositions',
    'agreement',
    'phonology_like',
    'capitalization',
    'punctuation',
    'other',
  };

  static List<String> parseTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final out = <String>[];
    for (final part in raw.split(',')) {
      var tag = part.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
      tag = _aliases[tag] ?? tag;
      if (!allowedTags.contains(tag) || out.contains(tag)) continue;
      out.add(tag);
      if (out.length >= 4) break;
    }
    return out;
  }

  static DictationLaunchArgs fromRoute(
    String route, {
    String fallbackLanguage = 'EN',
  }) {
    final uri = Uri.tryParse(
      route.contains('://') ? route : 'https://app$route',
    );
    final params = uri?.queryParameters ?? const <String, String>{};
    final lang = (params['lang'] ?? params['language'] ?? fallbackLanguage)
        .toUpperCase();
    final cefrRaw = (params['cefr'] ?? '').toUpperCase();
    final cefr = RegExp(r'^(A1|A2|B1|B2|C1|C2)$').hasMatch(cefrRaw)
        ? cefrRaw
        : null;
    final count = int.tryParse(params['count'] ?? '') ?? 10;
    return DictationLaunchArgs(
      language: lang.isEmpty ? fallbackLanguage : lang,
      cefr: cefr,
      focusTags: parseTags(params['tags']),
      sessionSize: count.clamp(3, 20),
      autoStartCalibrated: params['focus'] == 'calibrated',
    );
  }
}

bool isDictationAlmostCorrect(int score) => score >= 80 && score < 100;
