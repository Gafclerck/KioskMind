import 'package:flutter_test/flutter_test.dart';
import 'package:stt_tts_spike/src/phrase_book.dart';

/// The asset the spike measures with is written by `tool/select_spike_phrases.dart`
/// at the root of the repository, not by hand here. These tests cover the reading
/// side only: what the harness does with a malformed or unexpected asset must fail
/// loudly on a phone, where a silent empty list would look like thirty phrases
/// measured as nothing.
void main() {
  group('la lecture des phrases', () {
    test('lit les identifiants, les textes et les etiquettes', () {
      final PhraseBook book = decodePhraseBook(
        '{"source":"voice/golden/text_cases.json","phrases":['
        '{"id":"t001","text":"vendu deux savon","tags":["simple"]},'
        '{"id":"t042","text":"combien de riz","tags":["hard","numbers_words"]}]}',
      );

      expect(book.source, 'voice/golden/text_cases.json');
      expect(book.phrases, hasLength(2));
      expect(book.phrases.first.id, 't001');
      expect(book.phrases.first.text, 'vendu deux savon');
      expect(book.phrases.last.tags, <String>['hard', 'numbers_words']);
    });

    test('tolere une etiquette manquante plutot que de planter', () {
      final PhraseBook book = decodePhraseBook(
        '{"phrases":[{"id":"t001","text":"vendu un lait"}]}',
      );

      expect(book.phrases.single.tags, isEmpty);
    });

    test('nomme la source inconnue plutot que de la deviner', () {
      final PhraseBook book = decodePhraseBook('{"phrases":[]}');

      expect(book.source, 'inconnue');
      expect(book.phrases, isEmpty);
    });

    test('echoue bruyamment sur un JSON qui n est pas un objet', () {
      expect(() => decodePhraseBook('[]'), throwsA(isA<FormatException>()));
    });

    test('echoue bruyamment sur une liste de phrases absente', () {
      expect(
        () => decodePhraseBook('{"source":"x"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('echoue bruyamment sur une phrase qui n est pas un objet', () {
      expect(
        () => decodePhraseBook('{"phrases":["vendu un lait"]}'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
