import 'package:connectlang_app/features/vocabulary/models/vocab_enrich_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildEnrichedTranslationField', () {
    test('keeps a single gloss as-is', () {
      expect(buildEnrichedTranslationField('to run', null), 'to run');
    });

    test('merges main gloss with alternates up to the limit', () {
      final result = buildEnrichedTranslationField('correr', ['fugir', 'apressar-se']);
      expect(result, 'correr · fugir');
    });

    test('deduplicates case-insensitively between main and alternates', () {
      final result = buildEnrichedTranslationField('Run', ['run', 'sprint']);
      expect(result, 'Run · sprint');
    });

    test('splits an already-combined main gloss on the middle dot', () {
      final result = buildEnrichedTranslationField('correr · fugir', null);
      expect(result, 'correr · fugir');
    });

    test('truncates an overly long combined translation', () {
      final long = 'a' * 400;
      final result = buildEnrichedTranslationField(long, null);
      expect(result.length, lessThanOrEqualTo(320));
      expect(result.endsWith('…'), isTrue);
    });
  });
}
