import 'dart:math' as math;

/// Porte exato do algoritmo local de correção de `src/lib/dictation.ts`
/// (`scoreDictationAnswer`) — alinhamento de tokens via Levenshtein
/// ponderado, igual ao web. Nota local é sempre calculada primeiro (serve de
/// base e de fallback quando a IA falha/demora); `mergeDictationGrades`
/// combina com a resposta da edge function `dictation-grade`, porte de
/// `mergeDictationGrades` do mesmo arquivo web.
class DictationMistake {
  const DictationMistake({
    required this.expected,
    required this.answer,
    required this.index,
    required this.severity,
    this.note,
  });

  final String expected;
  final String answer;
  final int index;
  final String severity; // 'minor' | 'major'
  final String? note;

  Map<String, dynamic> toJson() => {
        'expected': expected,
        'answer': answer,
        'index': index,
        'severity': severity,
        if (note != null) 'note': note,
      };
}

class DictationScoreResult {
  const DictationScoreResult({required this.score, required this.mistakes});

  final int score;
  final List<DictationMistake> mistakes;
}

const Map<String, String> _diacriticMap = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
};

String _stripDiacritics(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticMap[char] ?? char);
  }
  return buffer.toString();
}

final RegExp _dictationPunctuation = RegExp('[“”"\'.`´’‘(),;:!?¿¡]');

String _normalizeForDictation(String value) {
  return value
      .toLowerCase()
      .replaceAll(_dictationPunctuation, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _levenshteinDistance(String a, String b) {
  final rows = a.length;
  final cols = b.length;
  final dp = List.generate(rows + 1, (_) => List<int>.filled(cols + 1, 0));
  for (var i = 0; i <= rows; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= cols; j++) {
    dp[0][j] = j;
  }
  for (var i = 1; i <= rows; i++) {
    for (var j = 1; j <= cols; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      dp[i][j] = math.min(dp[i - 1][j] + 1, math.min(dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost));
    }
  }
  return dp[rows][cols];
}

bool _isDoubledLetterNameVariant(String expected, String answer) {
  final expectedPlain = _stripDiacritics(expected);
  final answerPlain = _stripDiacritics(answer);
  if (expectedPlain == answerPlain) return false;
  if ((expectedPlain.length - answerPlain.length).abs() != 1) return false;
  final longer = expectedPlain.length > answerPlain.length ? expectedPlain : answerPlain;
  final shorter = expectedPlain.length > answerPlain.length ? answerPlain : expectedPlain;
  if (shorter.length < 3) return false;
  for (var i = 0; i < longer.length; i++) {
    final candidate = longer.substring(0, i) + longer.substring(i + 1);
    if (candidate == shorter) return true;
  }
  return false;
}

String _tokenMatchKind(String expected, String answer) {
  if (expected == answer) return 'exact';
  if (_isDoubledLetterNameVariant(expected, answer)) return 'exact';
  final expectedPlain = _stripDiacritics(expected);
  final answerPlain = _stripDiacritics(answer);
  if (expectedPlain == answerPlain) return 'exact';
  final minLength = math.min(expectedPlain.length, answerPlain.length);
  if (minLength < 4) return 'major';
  final distance = _levenshteinDistance(expectedPlain, answerPlain);
  if (distance <= 1) return 'minor';
  if (minLength >= 7 && distance <= 2 && distance / minLength <= 0.25) return 'minor';
  return 'major';
}

double _tokenAlignmentCost(String expected, String answer) {
  final kind = _tokenMatchKind(expected, answer);
  if (kind == 'exact') return 0;
  if (kind == 'minor') return 0.2;
  return 1;
}

enum _DiffOpType { match, minor, substitute, delete, insert }

class _DiffOp {
  const _DiffOp({
    required this.type,
    required this.expectedIndex,
    required this.answerIndex,
    this.expected,
    this.answer,
  });

  final _DiffOpType type;
  final String? expected;
  final String? answer;
  final int expectedIndex;
  final int answerIndex;
}

List<_DiffOp> _alignDictationTokens(List<String> expectedTokens, List<String> answerTokens) {
  final rows = expectedTokens.length;
  final cols = answerTokens.length;
  final dp = List.generate(rows + 1, (_) => List<double>.filled(cols + 1, 0));
  for (var i = 0; i <= rows; i++) {
    dp[i][0] = i.toDouble();
  }
  for (var j = 0; j <= cols; j++) {
    dp[0][j] = j.toDouble();
  }

  for (var i = 1; i <= rows; i++) {
    for (var j = 1; j <= cols; j++) {
      final substitutionCost = _tokenAlignmentCost(expectedTokens[i - 1], answerTokens[j - 1]);
      dp[i][j] = math.min(dp[i - 1][j - 1] + substitutionCost, math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1));
    }
  }

  final ops = <_DiffOp>[];
  var i = rows;
  var j = cols;

  while (i > 0 || j > 0) {
    final expected = i > 0 ? expectedTokens[i - 1] : '';
    final answer = j > 0 ? answerTokens[j - 1] : '';

    if (i > 0 && j > 0 && expected == answer && dp[i][j] == dp[i - 1][j - 1]) {
      ops.add(_DiffOp(type: _DiffOpType.match, expected: expected, answer: answer, expectedIndex: i - 1, answerIndex: j - 1));
      i -= 1;
      j -= 1;
      continue;
    }
    if (i > 0 && j > 0 && _tokenMatchKind(expected, answer) == 'exact' && expected != answer && dp[i][j] == dp[i - 1][j - 1]) {
      ops.add(_DiffOp(type: _DiffOpType.match, expected: expected, answer: answer, expectedIndex: i - 1, answerIndex: j - 1));
      i -= 1;
      j -= 1;
      continue;
    }
    if (i > 0 &&
        j > 0 &&
        _tokenMatchKind(expected, answer) == 'minor' &&
        dp[i][j] == dp[i - 1][j - 1] + _tokenAlignmentCost(expected, answer)) {
      ops.add(_DiffOp(type: _DiffOpType.minor, expected: expected, answer: answer, expectedIndex: i - 1, answerIndex: j - 1));
      i -= 1;
      j -= 1;
      continue;
    }
    if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
      ops.add(_DiffOp(type: _DiffOpType.delete, expected: expected, expectedIndex: i - 1, answerIndex: j));
      i -= 1;
      continue;
    }
    if (j > 0 && dp[i][j] == dp[i][j - 1] + 1) {
      ops.add(_DiffOp(type: _DiffOpType.insert, answer: answer, expectedIndex: i, answerIndex: j - 1));
      j -= 1;
      continue;
    }
    if (i > 0 && j > 0) {
      ops.add(_DiffOp(type: _DiffOpType.substitute, expected: expected, answer: answer, expectedIndex: i - 1, answerIndex: j - 1));
      i -= 1;
      j -= 1;
      continue;
    }
    break;
  }

  return ops.reversed.toList();
}

const double _minorMistakeWeight = 0.1;

DictationScoreResult scoreDictationAnswer(String expected, String answer) {
  final expectedTokens = _normalizeForDictation(expected).split(' ').where((t) => t.isNotEmpty).toList();
  final answerTokens = _normalizeForDictation(answer).split(' ').where((t) => t.isNotEmpty).toList();
  final total = math.max(expectedTokens.length, 1);
  final ops = _alignDictationTokens(expectedTokens, answerTokens);

  final mistakes = <DictationMistake>[];
  for (final op in ops) {
    switch (op.type) {
      case _DiffOpType.match:
        break;
      case _DiffOpType.minor:
        mistakes.add(DictationMistake(
          expected: op.expected!,
          answer: op.answer!,
          index: op.expectedIndex,
          severity: 'minor',
          note: '${op.answer} → ${op.expected}',
        ));
      case _DiffOpType.delete:
        mistakes.add(DictationMistake(expected: op.expected!, answer: '', index: op.expectedIndex, severity: 'major'));
      case _DiffOpType.insert:
        mistakes.add(DictationMistake(expected: '', answer: op.answer!, index: op.expectedIndex, severity: 'major'));
      case _DiffOpType.substitute:
        mistakes.add(
          DictationMistake(expected: op.expected!, answer: op.answer!, index: op.expectedIndex, severity: 'major'),
        );
    }
  }

  final majorMistakes = mistakes.where((m) => m.severity != 'minor').length;
  final minorMistakes = mistakes.where((m) => m.severity == 'minor').length;
  final penalty = majorMistakes + _minorMistakeWeight * minorMistakes;
  var score = ((total - penalty) / total * 100).round().clamp(0, 100);
  if (mistakes.isNotEmpty) score = math.min(score, 99);

  return DictationScoreResult(score: score, mistakes: mistakes);
}

/// Resultado final (local ou combinado com a IA) — porte de
/// `DictationGradingResult` do web.
class DictationGradingResult {
  const DictationGradingResult({required this.score, required this.mistakes, required this.source, this.feedback});

  final int score;
  final List<DictationMistake> mistakes;
  final String source; // 'local' | 'hybrid'
  final String? feedback;
}

DictationMistake _normalizeMistake(Map<String, dynamic> raw, int index) {
  final note = (raw['note'] as String?)?.trim();
  return DictationMistake(
    expected: (raw['expected'] as String? ?? '').trim(),
    answer: (raw['answer'] as String? ?? '').trim(),
    index: (raw['index'] as num?)?.toInt() ?? index,
    severity: raw['severity'] == 'minor' ? 'minor' : 'major',
    note: (note?.isNotEmpty ?? false) ? note : null,
  );
}

bool _isValidAiGrade(Map<String, dynamic>? raw, int expectedWordCount) {
  if (raw == null) return false;
  if (raw['score'] is! num) return false;
  final mistakes = raw['mistakes'];
  if (mistakes is! List) return false;
  if (mistakes.length > expectedWordCount + 8) return false;
  return mistakes.every((m) => m is Map);
}

/// Porte de `mergeDictationGrades` do web: combina a nota local (sempre
/// calculada) com a resposta da edge function `dictation-grade`, com as
/// mesmas salvaguardas (IA não pode zerar erros reais nem inflar a nota
/// quando o local já achou erro grave/typo).
DictationGradingResult mergeDictationGrades(DictationScoreResult local, Map<String, dynamic>? aiRow) {
  final expectedWordCount = math.max(1, local.mistakes.length + 4);
  if (!_isValidAiGrade(aiRow, expectedWordCount)) {
    return DictationGradingResult(score: local.score, mistakes: local.mistakes, source: 'local');
  }

  final aiMistakesRaw = (aiRow!['mistakes'] as List).whereType<Map>().toList();
  final mistakes = [
    for (var i = 0; i < aiMistakesRaw.length; i++) _normalizeMistake(Map<String, dynamic>.from(aiMistakesRaw[i]), i),
  ];
  final localMajor = local.mistakes.where((m) => m.severity != 'minor').length;
  final localMinor = local.mistakes.where((m) => m.severity == 'minor').length;
  final aiMajor = mistakes.where((m) => m.severity != 'minor').length;
  var score = (aiRow['score'] as num).round().clamp(0, 100);
  final feedback = (aiRow['feedback'] as String?)?.trim();

  // IA ignorou erros reais (omissões ou typos) — confia no local.
  if (local.mistakes.isNotEmpty && mistakes.isEmpty) {
    return DictationGradingResult(score: local.score, mistakes: local.mistakes, source: 'hybrid');
  }

  if (aiMajor > 0 && score == 100) score = local.score;
  if (aiMajor > localMajor + 2) score = math.min(score, local.score);
  // IA não pode inflar muito acima do local quando há erros graves.
  if (localMajor > 0 && score > local.score + 10) score = local.score;
  // Typos/acentos locais: não deixar a IA devolver 100%.
  if (localMinor > 0) score = math.min(math.min(score, local.score), 99);
  if (score < local.score - 25) score = local.score;
  if ((localMajor > 0 || localMinor > 0 || mistakes.isNotEmpty) && score >= 100) {
    score = math.min(99, local.score);
  }

  // Preferir notas locais de typo quando a IA não detalhou o minor.
  final mergedMistakes = localMinor > 0 && mistakes.every((m) => m.severity != 'minor')
      ? [...mistakes, ...local.mistakes.where((m) => m.severity == 'minor')]
      : [
          for (final m in mistakes)
            if (m.note != null)
              m
            else
              _withLocalTwinNote(m, local),
        ];

  return DictationGradingResult(
    score: score,
    mistakes: mergedMistakes,
    feedback: (feedback?.isNotEmpty ?? false) ? feedback : null,
    source: 'hybrid',
  );
}

DictationMistake _withLocalTwinNote(DictationMistake m, DictationScoreResult local) {
  for (final lm in local.mistakes) {
    if (lm.severity == 'minor' && lm.expected == m.expected && lm.answer == m.answer && lm.note != null) {
      return DictationMistake(expected: m.expected, answer: m.answer, index: m.index, severity: m.severity, note: lm.note);
    }
  }
  return m;
}
