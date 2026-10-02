import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/spoken_amount_formatter.dart';

/// The French reading of an amount, which is what the merchant actually hears.
///
/// A synthesiser reads "1250.0" as "mille deux cent cinquante point zéro", or as
/// nothing at all. Both are wrong for money, so the recap always goes through this
/// formatter. The XOF has no decimals (A1 of `USE_CASE_CONTRACTS.md`), so an amount
/// is rounded to the whole franc and the rules are those of ordinary French
/// numbers, not those of decimal reading.
void main() {
  const SpokenAmountFormatter formatter = SpokenAmountFormatter();

  group('les nombres en lettres', () {
    // One row per family of French rule, not one row per number: a table that
    // repeats a rule teaches nothing the previous row did not.
    final Map<double, String> words = <double, String>{
      0: 'zéro',
      1: 'un',
      7: 'sept',
      11: 'onze',
      16: 'seize',
      17: 'dix-sept',
      19: 'dix-neuf',
      20: 'vingt',
      21: 'vingt et un',
      22: 'vingt-deux',
      30: 'trente',
      31: 'trente et un',
      40: 'quarante',
      41: 'quarante et un',
      50: 'cinquante',
      51: 'cinquante et un',
      60: 'soixante',
      61: 'soixante et un',
      70: 'soixante-dix',
      71: 'soixante et onze',
      72: 'soixante-douze',
      79: 'soixante-dix-neuf',
      80: 'quatre-vingts',
      81: 'quatre-vingt-un',
      82: 'quatre-vingt-deux',
      90: 'quatre-vingt-dix',
      91: 'quatre-vingt-onze',
      99: 'quatre-vingt-dix-neuf',
      100: 'cent',
      101: 'cent un',
      200: 'deux cents',
      201: 'deux cent un',
      280: 'deux cent quatre-vingts',
      300: 'trois cents',
      700: 'sept cents',
      999: 'neuf cent quatre-vingt-dix-neuf',
      1000: 'mille',
      1001: 'mille un',
      2000: 'deux mille',
      11000: 'onze mille',
      21000: 'vingt et un mille',
      201000: 'deux cent un mille',
      1000000: 'un million',
      1000001: 'un million un',
      2000000: 'deux millions',
      2500000: 'deux millions cinq cent mille',
    };

    // The s of "cent" and of "vingt" belongs to the last group said, not to the
    // group that carries the digit: "cinq cents" but "cinq cent mille".
    words.addAll(<double, String>{
      800: 'huit cents',
      100000: 'cent mille',
      200000: 'deux cent mille',
      80000: 'quatre-vingt mille',
      180000: 'cent quatre-vingt mille',
      280000: 'deux cent quatre-vingt mille',
      71000: 'soixante et onze mille',
      80000000: 'quatre-vingt millions',
    });

    for (final MapEntry<double, String> row in words.entries) {
      test('${row.key} se dit « ${row.value} »', () {
        expect(formatter(row.key), row.value);
      });
    }
  });

  group('un montant se dit en francs entiers', () {
    test('le prix d une ligne de vente', () {
      expect(formatter(560), 'cinq cent soixante');
    });

    test('un double déjà entier ne prend pas de décimale parasite', () {
      expect(formatter(560.0), 'cinq cent soixante');
    });

    test('une fraction est arrondie au franc le plus proche', () {
      expect(formatter(1250.49), 'mille deux cent cinquante');
      expect(formatter(1250.5), 'mille deux cent cinquante et un');
    });

    test('un prix annoncé au kilo reste lisible', () {
      expect(formatter(100), 'cent');
    });
  });

  group('ce que la monnaie refuse', () {
    test('un montant négatif, qui ne veut rien dire en XOF', () {
      expect(() => formatter(-100), throwsArgumentError);
    });

    test('un montant qui n est pas un nombre', () {
      expect(() => formatter(double.nan), throwsArgumentError);
      expect(() => formatter(double.infinity), throwsArgumentError);
    });
  });
}
