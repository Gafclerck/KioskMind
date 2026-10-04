import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/product_alias_generator.dart';

void main() {
  group('ProductAliasGenerator', () {
    test('returns empty list for empty or whitespace product name', () {
      expect(ProductAliasGenerator.generate(''), isEmpty);
      expect(ProductAliasGenerator.generate('   '), isEmpty);
    });

    test('generates expected aliases for packaged rice with weight', () {
      final List<String> aliases = ProductAliasGenerator.generate(
        'Sac de riz 50kg',
      );

      expect(aliases, contains('sac de riz 50kg'));
      expect(aliases, contains('sac de riz'));
      expect(aliases, contains('riz'));
    });

    test('generates expected aliases for cooking oil with volume', () {
      final List<String> aliases = ProductAliasGenerator.generate(
        'Huile Dinor 1.5L',
      );

      expect(aliases, contains('huile dinor 1.5l'));
      expect(aliases, contains('huile dinor'));
      expect(aliases, contains('dinor'));
      expect(aliases, contains('huile'));
    });

    test('generates expected aliases for simple multi-word product', () {
      final List<String> aliases = ProductAliasGenerator.generate('Riz blanc');

      expect(aliases, contains('riz blanc'));
      expect(aliases, contains('riz'));
      expect(aliases, contains('blanc'));
    });

    test('generates expected aliases for soap with weight and origin', () {
      final List<String> aliases = ProductAliasGenerator.generate(
        'Savon de Marseille 200g',
      );

      expect(aliases, contains('savon de marseille 200g'));
      expect(aliases, contains('savon de marseille'));
      expect(aliases, contains('marseille'));
      expect(aliases, contains('savon'));
    });

    test('generates expected unaccented aliases', () {
      final List<String> aliases = ProductAliasGenerator.generate(
        'Riz parfumé',
      );

      expect(aliases, contains('riz parfumé'));
      expect(aliases, contains('riz parfume'));
      expect(aliases, contains('riz'));
      expect(aliases, contains('parfume'));
    });

    test('generates expected aliases for single word product', () {
      final List<String> aliases = ProductAliasGenerator.generate('Riz');

      expect(aliases, contains('riz'));
      expect(aliases.length, 1);
    });

    test('orders aliases by descending token length then length', () {
      final List<String> aliases = ProductAliasGenerator.generate(
        'Sac de riz 50kg',
      );

      // First aliases have more tokens than later ones
      final int firstTokenCount = aliases.first.split(' ').length;
      final int lastTokenCount = aliases.last.split(' ').length;
      expect(firstTokenCount, greaterThanOrEqualTo(lastTokenCount));
    });
  });
}
