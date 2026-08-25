import 'package:connectlang_app/features/placement/models/placement_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dictationScoreToCefr', () {
    test('score above keep threshold keeps the item CEFR', () {
      expect(dictationScoreToCefr(90, 'B2'), 'B2');
    });

    test('70-84 drops one band', () {
      expect(dictationScoreToCefr(75, 'B2'), 'B1');
    });

    test('50-69 drops two bands', () {
      expect(dictationScoreToCefr(60, 'B2'), 'A2');
    });

    test('very low score never drops below A1', () {
      expect(dictationScoreToCefr(0, 'A2'), 'A1');
    });
  });

  group('placementProductionNeedsWork', () {
    test('short answer relative to source needs work', () {
      final needsWork = placementProductionNeedsWork(
        answer: 'oi',
        sourcePt: 'Eu gostaria de saber onde fica a estação de trem mais próxima.',
      );
      expect(needsWork, isTrue);
    });

    test('solid translation at the same CEFR does not need work', () {
      final needsWork = placementProductionNeedsWork(
        productionCefr: 'B2',
        promptCefr: 'B2',
        answer: 'I would like to know where the nearest train station is.',
        sourcePt: 'Eu gostaria de saber onde fica a estação de trem mais próxima.',
      );
      expect(needsWork, isFalse);
    });

    test('judge showModel forces needs-work regardless of CEFR gap', () {
      final needsWork = placementProductionNeedsWork(
        showModel: true,
        productionCefr: 'B2',
        promptCefr: 'B2',
        answer: 'I would like to know where the nearest train station is.',
        sourcePt: 'Eu gostaria de saber onde fica a estação de trem mais próxima.',
      );
      expect(needsWork, isTrue);
    });

    test('dictation score below keep threshold needs work', () {
      final needsWork = placementProductionNeedsWork(dictationScore: 50, answer: 'anything');
      expect(needsWork, isTrue);
    });
  });

  group('placementSoftPassCefr', () {
    test('exact match keeps the item CEFR', () {
      expect(placementSoftPassCefr(productionCefr: 'B1', itemCefr: 'B1', needsWork: false), 'B1');
    });

    test('one band below with no red flags soft-passes to item CEFR', () {
      expect(placementSoftPassCefr(productionCefr: 'A2', itemCefr: 'B1', needsWork: false), 'B1');
    });

    test('one band below with needsWork keeps the judged CEFR', () {
      expect(placementSoftPassCefr(productionCefr: 'A2', itemCefr: 'B1', needsWork: true), 'A2');
    });

    test('two bands below never soft-passes', () {
      expect(placementSoftPassCefr(productionCefr: 'A1', itemCefr: 'B2', needsWork: false), 'A1');
    });
  });
}
