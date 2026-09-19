import 'package:connectlang_app/features/library/tappable_reading_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tap selects a word and a second tap expands to the phrase', () {
    const paragraph = 'They went to the park yesterday.';
    final tokens = tokenizeReadingParagraph(paragraph);

    final first = selectionFromTap(
      current: null,
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: 2,
      tokens: tokens,
    );
    expect(first?.text, 'went');

    final phrase = selectionFromTap(
      current: first,
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: 8,
      tokens: tokens,
    );
    expect(phrase?.text, 'went to the park');
  });

  test('tapping the same single word clears the selection', () {
    const paragraph = 'They went to the park.';
    final tokens = tokenizeReadingParagraph(paragraph);
    final first = selectionFromTap(
      current: null,
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: 2,
      tokens: tokens,
    );
    final cleared = selectionFromTap(
      current: first,
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: 2,
      tokens: tokens,
    );
    expect(cleared, isNull);
  });

  test('tapping a selected edge word unclicks it from the phrase', () {
    const paragraph = 'They went to the park yesterday.';
    final tokens = tokenizeReadingParagraph(paragraph);
    final phrase = selectionFromTap(
      current: selectionFromTap(
        current: null,
        scope: 'body',
        paragraphIndex: 0,
        tokenIndex: 2,
        tokens: tokens,
      ),
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: 8,
      tokens: tokens,
    );
    expect(phrase?.text, 'went to the park');

    final withoutStart = selectionFromTap(
      current: phrase,
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: 2,
      tokens: tokens,
    );
    expect(withoutStart?.text, 'to the park');

    final withoutEnd = selectionFromTap(
      current: withoutStart,
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: 8,
      tokens: tokens,
    );
    expect(withoutEnd?.text, 'to the');
  });

  test('tapping a selected word in the middle clears the phrase', () {
    const paragraph = 'They went to the park yesterday.';
    final tokens = tokenizeReadingParagraph(paragraph);
    final phrase = selectionFromTap(
      current: selectionFromTap(
        current: null,
        scope: 'body',
        paragraphIndex: 0,
        tokenIndex: 2,
        tokens: tokens,
      ),
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: 8,
      tokens: tokens,
    );

    final cleared = selectionFromTap(
      current: phrase,
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: 6,
      tokens: tokens,
    );
    expect(cleared, isNull);
  });

  test('long press selects the whole sentence', () {
    const paragraph = 'Hello there. They went to the park yesterday.';
    final tokens = tokenizeReadingParagraph(paragraph);
    final wentIndex = tokens.indexWhere((token) => token.text.startsWith('went'));
    final selected = selectionFromSentence(
      scope: 'body',
      paragraphIndex: 0,
      tokenIndex: wentIndex,
      tokens: tokens,
    );
    expect(selected.text, 'They went to the park yesterday.');
  });
}
