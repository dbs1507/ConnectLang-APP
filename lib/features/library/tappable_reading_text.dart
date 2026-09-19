import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/theme/app_colors.dart';
import 'models/inline_translation.dart';

class ReadingToken {
  const ReadingToken({required this.text, required this.isWord});

  final String text;
  final bool isWord;
}

class ReadingSelection {
  const ReadingSelection({
    required this.scope,
    required this.paragraphIndex,
    required this.startToken,
    required this.endToken,
    required this.text,
  });

  final String scope;
  final int paragraphIndex;
  final int startToken;
  final int endToken;
  final String text;

  bool contains(String scope, int paragraphIndex, int tokenIndex) {
    if (this.scope != scope || this.paragraphIndex != paragraphIndex) {
      return false;
    }
    final from = startToken < endToken ? startToken : endToken;
    final to = startToken < endToken ? endToken : startToken;
    return tokenIndex >= from && tokenIndex <= to;
  }
}

List<ReadingToken> tokenizeReadingParagraph(String paragraph) {
  return [
    for (final match in RegExp(r'\S+|\s+').allMatches(paragraph))
      ReadingToken(
        text: match.group(0)!,
        isWord: match.group(0)!.contains(RegExp(r'\S')),
      ),
  ];
}

String joinReadingTokens(List<ReadingToken> tokens, int start, int end) {
  if (tokens.isEmpty) return '';
  final from = (start < end ? start : end).clamp(0, tokens.length - 1);
  final to = (start < end ? end : start).clamp(0, tokens.length - 1);
  return tokens.sublist(from, to + 1).map((token) => token.text).join().trim();
}

(int, int) sentenceTokenBounds(List<ReadingToken> tokens, int index) {
  if (tokens.isEmpty) return (0, 0);
  final safeIndex = index.clamp(0, tokens.length - 1);
  var start = safeIndex;
  var end = safeIndex;
  bool closesSentence(ReadingToken token) =>
      token.isWord && RegExp(r'''[.!?…]["')\]]*$''').hasMatch(token.text.trim());

  for (var i = safeIndex - 1; i >= 0; i--) {
    if (closesSentence(tokens[i])) break;
    start = i;
  }
  for (var i = safeIndex; i < tokens.length; i++) {
    end = i;
    if (closesSentence(tokens[i])) break;
  }
  while (start < end && !tokens[start].isWord) {
    start += 1;
  }
  while (end > start && !tokens[end].isWord) {
    end -= 1;
  }
  return (start, end);
}

String plainReadingContent(String content) {
  var text = content.replaceAll('\r\n', '\n');
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (match) => match[1]!,
  );
  text = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (match) => match[1]!);
  text = text.replaceAllMapped(RegExp(r'__(.+?)__'), (match) => match[1]!);
  text = text.replaceAllMapped(
    RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'),
    (match) => match[1]!,
  );
  text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
  text = text.replaceAll('`', '');
  return text.trim();
}

List<String> readingParagraphs(String content) {
  return splitReadingParagraphs(plainReadingContent(content));
}

ReadingSelection? selectionFromTap({
  required ReadingSelection? current,
  required String scope,
  required int paragraphIndex,
  required int tokenIndex,
  required List<ReadingToken> tokens,
}) {
  if (tokenIndex < 0 ||
      tokenIndex >= tokens.length ||
      !tokens[tokenIndex].isWord) {
    return current;
  }

  if (current == null ||
      current.scope != scope ||
      current.paragraphIndex != paragraphIndex) {
    return ReadingSelection(
      scope: scope,
      paragraphIndex: paragraphIndex,
      startToken: tokenIndex,
      endToken: tokenIndex,
      text: joinReadingTokens(tokens, tokenIndex, tokenIndex),
    );
  }

  if (current.contains(scope, paragraphIndex, tokenIndex)) {
    return _unclickToken(current, tokenIndex, tokens);
  }

  final start = current.startToken < tokenIndex
      ? current.startToken
      : tokenIndex;
  final end = current.endToken > tokenIndex ? current.endToken : tokenIndex;
  return ReadingSelection(
    scope: scope,
    paragraphIndex: paragraphIndex,
    startToken: start,
    endToken: end,
    text: joinReadingTokens(tokens, start, end),
  );
}

ReadingSelection? _unclickToken(
  ReadingSelection current,
  int tokenIndex,
  List<ReadingToken> tokens,
) {
  final from = current.startToken < current.endToken
      ? current.startToken
      : current.endToken;
  final to = current.startToken < current.endToken
      ? current.endToken
      : current.startToken;

  if (from == to) return null;

  int? nearestWord(int start, int limit, int step) {
    for (var i = start; step > 0 ? i <= limit : i >= limit; i += step) {
      if (tokens[i].isWord) return i;
    }
    return null;
  }

  if (tokenIndex == from) {
    final next = nearestWord(from + 1, to, 1);
    if (next == null) return null;
    return ReadingSelection(
      scope: current.scope,
      paragraphIndex: current.paragraphIndex,
      startToken: next,
      endToken: to,
      text: joinReadingTokens(tokens, next, to),
    );
  }

  if (tokenIndex == to) {
    final prev = nearestWord(to - 1, from, -1);
    if (prev == null) return null;
    return ReadingSelection(
      scope: current.scope,
      paragraphIndex: current.paragraphIndex,
      startToken: from,
      endToken: prev,
      text: joinReadingTokens(tokens, from, prev),
    );
  }

  return null;
}

ReadingSelection selectionFromSentence({
  required String scope,
  required int paragraphIndex,
  required int tokenIndex,
  required List<ReadingToken> tokens,
}) {
  final bounds = sentenceTokenBounds(tokens, tokenIndex);
  return ReadingSelection(
    scope: scope,
    paragraphIndex: paragraphIndex,
    startToken: bounds.$1,
    endToken: bounds.$2,
    text: joinReadingTokens(tokens, bounds.$1, bounds.$2),
  );
}

class TappableReadingParagraph extends StatelessWidget {
  const TappableReadingParagraph({
    super.key,
    required this.text,
    required this.style,
    required this.onTapToken,
    required this.onLongPressToken,
    this.selectedStart,
    this.selectedEnd,
  });

  final String text;
  final TextStyle style;
  final int? selectedStart;
  final int? selectedEnd;
  final ValueChanged<int> onTapToken;
  final ValueChanged<int> onLongPressToken;

  @override
  Widget build(BuildContext context) {
    final tokens = tokenizeReadingParagraph(text);
    final from = selectedStart == null || selectedEnd == null
        ? null
        : (selectedStart! < selectedEnd! ? selectedStart! : selectedEnd!);
    final to = selectedStart == null || selectedEnd == null
        ? null
        : (selectedStart! < selectedEnd! ? selectedEnd! : selectedStart!);

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < tokens.length; i++)
            if (!tokens[i].isWord)
              TextSpan(text: tokens[i].text, style: style)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTapToken(i);
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    onLongPressToken(i);
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: from != null && to != null && i >= from && i <= to
                          ? AppColors.primary.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 1,
                        vertical: 1,
                      ),
                      child: Text(tokens[i].text, style: style),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
