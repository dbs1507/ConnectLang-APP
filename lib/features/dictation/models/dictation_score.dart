import 'dart:math' as math;

/// Porte exato do algoritmo local de correção de `src/lib/dictation.ts`
/// (`scoreDictationAnswer`) — alinhamento de tokens via Levenshtein
/// ponderado, igual ao web. O app não chama a edge function `dictation-grade`
/// (IA) nesta fatia; toda nota vem por este caminho local, que é o mesmo
/// fallback que o web usa quando a IA falha ou demora — `gradingSource`
/// sempre 'local' aqui.
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
