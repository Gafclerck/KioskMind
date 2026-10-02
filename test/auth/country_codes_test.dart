import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/auth/domain/country_codes.dart';

void main() {
  test('splits the longest dial-code prefix from a number', () {
    final ({String countryCode, String phone})? result = splitPhoneNumber(
      '+2250700000000',
    );

    expect(result, isNotNull);
    expect(result!.countryCode, '+225');
    expect(result.phone, '0700000000');
  });

  test('picks the longer code before a shorter one sharing its prefix', () {
    final ({String countryCode, String phone})? result = splitPhoneNumber(
      '+2250700000000',
    );

    expect(result!.countryCode, '+225');
    expect(result.phone, '0700000000');
  });

  test('splits a two-digit code like France or the UK', () {
    final ({String countryCode, String phone})? france = splitPhoneNumber(
      '+33607000000',
    );
    expect(france!.countryCode, '+33');
    expect(france.phone, '607000000');

    final ({String countryCode, String phone})? uk = splitPhoneNumber(
      '+447911123456',
    );
    expect(uk!.countryCode, '+44');
    expect(uk.phone, '7911123456');
  });

  test('splits a three-digit +1 North American number', () {
    final ({String countryCode, String phone})? usa = splitPhoneNumber(
      '+13015550123',
    );
    expect(usa!.countryCode, '+1');
    expect(usa.phone, '3015550123');
  });

  test('returns null for a number with a leading zero', () {
    expect(splitPhoneNumber('0700000000'), isNull);
  });

  test('returns null for a bare dial code', () {
    expect(splitPhoneNumber('+225'), isNull);
  });

  test('returns null for garbage that matches no code', () {
    expect(splitPhoneNumber('+999123456'), isNull);
  });
}
