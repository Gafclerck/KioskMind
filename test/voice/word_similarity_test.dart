import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/word_similarity.dart';

void main() {
  group('of', () {
    test('mots identiques', () {
      expect(WordSimilarity.of('maggi', 'maggi'), 1);
    });

    test('une faute sur un long mot reste proche', () {
      expect(WordSimilarity.of('magis', 'maggi'), closeTo(0.6, 0.0001));
      expect(WordSimilarity.of('sachett', 'sachet'), closeTo(0.857, 0.001));
    });

    test('deux fautes sur huit lettres tombent sous le seuil', () {
      // Mesure figee: c'est elle qui refuse "conssrv" pour "conserve".
      // Abaisser le seuil de VoiceConfig pour l'accepter est une decision a
      // prendre explicitement, pas un effet de bord de codage.
      expect(WordSimilarity.of('conssrv', 'conserve'), closeTo(0.75, 0.0001));
      expect(
        WordSimilarity.of('conssrv', 'conserve') < kFuzzyThresholdUsedByTests,
        isTrue,
      );
    });

    test('symetrique', () {
      expect(
        WordSimilarity.of('savon', 'savons'),
        WordSimilarity.of('savons', 'savon'),
      );
    });

    test('deux mots vides ne donnent pas une division par zero', () {
      expect(WordSimilarity.of('', ''), 1);
    });

    test('un mot vide ne ressemble a rien', () {
      expect(WordSimilarity.of('', 'sucre'), 0);
    });

    test('rien en commun', () {
      expect(WordSimilarity.of('riz', 'ciment'), lessThan(0.3));
    });
  });

  group('nounForms', () {
    test('le mot lui meme est toujours propose', () {
      expect(WordSimilarity.nounForms('sucre'), contains('sucre'));
      expect(WordSimilarity.nounForms('sucre'), hasLength(1));
    });

    test('un -s final', () {
      expect(WordSimilarity.nounForms('rizs'), contains('riz'));
    });

    test('un -es final donne les deux orthographes', () {
      final List<String> forms = WordSimilarity.nounForms('cassonades');
      expect(forms, contains('cassonad'));
      expect(forms, contains('cassonads'));
    });

    test('un -aux final', () {
      expect(WordSimilarity.nounForms('rizaux'), contains('riz'));
    });

    test('un -eaux final', () {
      expect(WordSimilarity.nounForms('gateaux'), contains('gateau'));
    });
  });
}

/// Seuil que ces tests considers comme la frontiere du mot inconnu.
///
/// Valeur du defaut de `VoiceConfig.fuzzyThreshold`, reprise ici pour que le test
/// qui fige "conssrv" depende d'un nombre explicite et non d'une lecture du
/// defaut a l'execution.
const double kFuzzyThresholdUsedByTests = 0.78;
