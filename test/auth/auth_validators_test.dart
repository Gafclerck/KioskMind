import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/auth/domain/auth_validators.dart';

void main() {
  group('isEmail', () {
    test('accepts well-formed addresses', () {
      expect(isEmail('user@example.com'), isTrue);
      expect(isEmail('user.name+tag@sub.domain.co'), isTrue);
    });

    test('rejects malformed addresses', () {
      expect(isEmail('plain text'), isFalse);
      expect(isEmail('user@'), isFalse);
      expect(isEmail('@example.com'), isFalse);
      expect(isEmail(''), isFalse);
    });
  });

  group('validatePhoneNumber', () {
    test('rejects empty and null values', () {
      expect(validatePhoneNumber(null), 'Saisissez votre numéro de téléphone');
      expect(validatePhoneNumber(''), 'Saisissez votre numéro de téléphone');
    });

    test('accepts 8 to 15 digits with optional international prefix', () {
      expect(validatePhoneNumber('0700000000'), isNull);
      expect(validatePhoneNumber('+2250700000000'), isNull);
      expect(validatePhoneNumber('12345678'), isNull);
      expect(validatePhoneNumber('123456789012345'), isNull);
    });

    test('ignores separators', () {
      expect(validatePhoneNumber('07 00 00 00 00'), isNull);
      expect(validatePhoneNumber('07-00-00-00-00'), isNull);
      expect(validatePhoneNumber('+225 (07) 00 00 00'), isNull);
    });

    test('rejects out-of-range lengths and non digits', () {
      expect(
        validatePhoneNumber('1234567'),
        'Numéro invalide (8 à 15 chiffres)',
      );
      expect(
        validatePhoneNumber('1234567890123456'),
        'Numéro invalide (8 à 15 chiffres)',
      );
      expect(
        validatePhoneNumber('abcdefgh'),
        'Numéro invalide (8 à 15 chiffres)',
      );
    });
  });

  group('validateEmail', () {
    test('rejects empty values', () {
      expect(validateEmail(null), 'Saisissez votre adresse e-mail');
      expect(validateEmail('   '), 'Saisissez votre adresse e-mail');
    });

    test('rejects malformed addresses', () {
      expect(validateEmail('not-an-email'), 'Adresse e-mail invalide');
      expect(validateEmail('user@'), 'Adresse e-mail invalide');
    });

    test('accepts well-formed addresses', () {
      expect(validateEmail('user@example.com'), isNull);
      expect(validateEmail('  user@example.com '), isNull);
    });
  });

  group('validateIdentifier', () {
    test('rejects empty values', () {
      expect(validateIdentifier(null), 'Saisissez votre téléphone ou e-mail');
      expect(validateIdentifier(''), 'Saisissez votre téléphone ou e-mail');
    });

    test('accepts a phone number', () {
      expect(validateIdentifier('0700000000'), isNull);
    });

    test('accepts an email address', () {
      expect(validateIdentifier('user@example.com'), isNull);
    });

    test('rejects a malformed identifier', () {
      expect(validateIdentifier('abc'), 'Numéro invalide (8 à 15 chiffres)');
    });
  });

  group('validatePassword', () {
    test('rejects empty values', () {
      expect(validatePassword(null), 'Saisissez votre mot de passe');
      expect(validatePassword(''), 'Saisissez votre mot de passe');
    });

    test('rejects passwords shorter than 8 characters', () {
      expect(validatePassword('1234567'), '8 caractères minimum');
    });

    test('accepts passwords of at least 8 characters', () {
      expect(validatePassword('12345678'), isNull);
    });
  });

  group('validateFullName', () {
    test('rejects empty values', () {
      expect(validateFullName(null), 'Nom complet requis');
      expect(validateFullName('  '), 'Nom complet requis');
    });

    test('requires first and last name', () {
      expect(validateFullName('David'), 'Saisissez votre nom et votre prénom');
    });

    test('accepts a full name', () {
      expect(validateFullName('David Koné'), isNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('rejects empty confirmation', () {
      expect(
        validatePasswordConfirmation('password123', null),
        'Confirmez votre mot de passe',
      );
      expect(
        validatePasswordConfirmation('password123', ''),
        'Confirmez votre mot de passe',
      );
    });

    test('rejects a mismatch', () {
      expect(
        validatePasswordConfirmation('password123', 'password456'),
        'Les mots de passe ne correspondent pas',
      );
    });

    test('accepts a match', () {
      expect(
        validatePasswordConfirmation('password123', 'password123'),
        isNull,
      );
    });
  });

  group('validateTermsAccepted', () {
    test('rejects an unchecked box', () {
      expect(
        validateTermsAccepted(false),
        'Vous devez accepter les conditions',
      );
      expect(validateTermsAccepted(null), 'Vous devez accepter les conditions');
    });

    test('accepts a checked box', () {
      expect(validateTermsAccepted(true), isNull);
    });
  });
}
