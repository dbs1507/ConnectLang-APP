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
}
