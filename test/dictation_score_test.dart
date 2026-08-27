import 'package:connectlang_app/features/dictation/models/dictation_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('perfect answer scores 100 with no mistakes', () {
    final result = scoreDictationAnswer('I like ice cream', 'I like ice cream');
    expect(result.score, 100);
    expect(result.mistakes, isEmpty);
  });

  test('single-letter typo is a minor mistake, capped below 100', () {
    final result = scoreDictationAnswer('I like ice cream', 'I like ice creem');
    expect(result.mistakes, hasLength(1));
    expect(result.mistakes.single.severity, 'minor');
    expect(result.score, lessThan(100));
    expect(result.score, greaterThanOrEqualTo(90));
  });

  test('missing word is a major mistake', () {
    final result = scoreDictationAnswer('I like ice cream', 'I like cream');
    expect(result.mistakes, hasLength(1));
    expect(result.mistakes.single.severity, 'major');
    expect(result.mistakes.single.expected, 'ice');
    expect(result.mistakes.single.answer, isEmpty);
  });

  test('extra word is a major mistake', () {
    final result = scoreDictationAnswer('I like ice cream', 'I really like ice cream');
    expect(result.mistakes, hasLength(1));
    expect(result.mistakes.single.severity, 'major');
    expect(result.mistakes.single.answer, 'really');
  });

  test('completely different sentence scores near 0', () {
    final result = scoreDictationAnswer('I like ice cream', 'xyz qwe rty');
    expect(result.score, lessThan(30));
  });

  test('punctuation and case are ignored', () {
    final result = scoreDictationAnswer('Hello, world!', 'hello world');
    expect(result.score, 100);
    expect(result.mistakes, isEmpty);
  });

  test('accents are treated as exact matches', () {
    final result = scoreDictationAnswer('café com açúcar', 'cafe com acucar');
    expect(result.score, 100);
    expect(result.mistakes, isEmpty);
  });

  test('empty answer scores 0 with a mistake per word', () {
    final result = scoreDictationAnswer('I like ice cream', '');
    expect(result.score, 0);
    expect(result.mistakes, hasLength(4));
    expect(result.mistakes.every((m) => m.severity == 'major'), isTrue);
  });

  group('mergeDictationGrades', () {
    test('invalid AI response falls back to local', () {
      final local = scoreDictationAnswer('I like ice cream', 'I like ice cream');
      final merged = mergeDictationGrades(local, null);
      expect(merged.source, 'local');
      expect(merged.score, local.score);
    });

    test('AI response with too many mistakes is rejected as invalid', () {
      final local = scoreDictationAnswer('I like ice cream', 'I like ice cream');
      final merged = mergeDictationGrades(local, {
        'score': 50,
        'mistakes': List.generate(20, (_) => {'expected': 'x', 'answer': 'y', 'index': 0, 'severity': 'major'}),
      });
      expect(merged.source, 'local');
    });

    test('AI ignoring real local mistakes falls back to local score', () {
      final local = scoreDictationAnswer('I like ice cream', 'I like cream');
      final merged = mergeDictationGrades(local, {'score': 100, 'mistakes': []});
      expect(merged.source, 'hybrid');
      expect(merged.score, local.score);
      expect(merged.mistakes, local.mistakes);
    });

    test('AI cannot inflate to 100 when local found a major mistake', () {
      final local = scoreDictationAnswer('I like ice cream', 'I like cream');
      final merged = mergeDictationGrades(local, {
        'score': 100,
        'mistakes': [
          {'expected': 'ice', 'answer': '', 'index': 2, 'severity': 'major'},
        ],
      });
      expect(merged.score, lessThan(100));
    });

    test('AI cannot inflate far above local when it under-counts major mistakes', () {
      final local = scoreDictationAnswer('I really like ice cream today', 'cream');
      final merged = mergeDictationGrades(local, {
        'score': 95,
        'mistakes': [
          {'expected': 'today', 'answer': '', 'index': 5, 'severity': 'major'},
        ],
      });
      expect(merged.score, lessThanOrEqualTo(local.score));
    });

    test('local minor typo notes are preserved when AI omits minor severity', () {
      final local = scoreDictationAnswer('I like ice cream', 'I like ice creem');
      final merged = mergeDictationGrades(local, {
        'score': 90,
        'mistakes': [
          {'expected': 'cream', 'answer': 'creem', 'index': 3, 'severity': 'major'},
        ],
      });
      expect(merged.source, 'hybrid');
      expect(merged.mistakes.any((m) => m.severity == 'minor'), isTrue);
    });
  });
}
