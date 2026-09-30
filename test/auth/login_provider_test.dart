import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/auth/domain/auth_gateway.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_gateway_provider.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/login_provider.dart';

import 'fakes.dart';

ProviderContainer makeContainer(FakeAuthGateway gateway) {
  return ProviderContainer(
    overrides: [authGatewayProvider.overrideWithValue(gateway)],
  );
}

void main() {
  test('starts in phone mode with empty fields', () {
    final ProviderContainer container = makeContainer(FakeAuthGateway());
    addTearDown(container.dispose);

    final LoginState state = container.read(loginProvider);
    expect(state.emailMode, isFalse);
    expect(state.identifier, isEmpty);
    expect(state.password, isEmpty);
    expect(state.isSubmitting, isFalse);
    expect(state.success, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.otpRequested, isFalse);
    expect(state.otpVerificationId, isNull);
    expect(state.successMessage, isNull);
  });

  test('submits and signs in with email credentials', () async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.toggleIdentifierMode();
    notifier.setIdentifier('david@example.com');
    notifier.setPassword('password123');

    await notifier.submit();

    final LoginState state = container.read(loginProvider);
    expect(gateway.signInCalls, 1);
    expect(gateway.lastSignInEmail, 'david@example.com');
    expect(state.isSubmitting, isFalse);
    expect(state.success, isTrue);
  });

  test(
    'normalizes a local phone number to +225 when requesting a code',
    () async {
      final FakeAuthGateway gateway = FakeAuthGateway();
      final ProviderContainer container = makeContainer(gateway);
      addTearDown(container.dispose);

      final LoginNotifier notifier = container.read(loginProvider.notifier);
      notifier.setIdentifier('07 00 00 00 00');
      notifier.setPassword('password123');

      await notifier.submit();

      expect(gateway.sendPhoneCodeCalls, 1);
      expect(gateway.lastPhoneNumber, '+2250700000000');
      final LoginState state = container.read(loginProvider);
      expect(state.otpRequested, isTrue);
      expect(state.otpVerificationId, 'verification-id');
      expect(state.success, isFalse);
    },
  );

  test('keeps an already international phone number untouched', () async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.setIdentifier('+33612345678');
    notifier.setPassword('password123');

    await notifier.submit();

    expect(gateway.lastPhoneNumber, '+33612345678');
  });

  test('exposes the French message when sending the code fails', () async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSendPhoneCode:
          ({
            required String phoneNumber,
            required void Function(String verificationId) onCodeSent,
            required void Function(AuthException error) onError,
          }) {
            onError(const AuthException('Numéro de téléphone invalide'));
          },
    );
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.setIdentifier('123');
    notifier.setPassword('password123');

    await notifier.submit();

    final LoginState state = container.read(loginProvider);
    expect(state.errorMessage, 'Numéro de téléphone invalide');
    expect(state.otpRequested, isFalse);
  });

  test('verifies the phone OTP and succeeds on phone login', () async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.setIdentifier('0700000000');
    notifier.setPassword('password123');
    await notifier.submit();
    expect(container.read(loginProvider).otpRequested, isTrue);

    final bool verified = await notifier.verifyPhoneOtp('123456');

    expect(verified, isTrue);
    expect(gateway.verifyPhoneCredentialCalls, 1);
    expect(gateway.lastSmsCode, '123456');
    expect(gateway.lastVerificationId, 'verification-id');
    final LoginState state = container.read(loginProvider);
    expect(state.otpRequested, isFalse);
    expect(state.success, isTrue);
    expect(state.successMessage, 'Code vérifié, connexion réussie');
  });

  test(
    'keeps OTP state and exposes the message when the code is invalid',
    () async {
      final FakeAuthGateway gateway = FakeAuthGateway(
        onVerifyPhoneCredential:
            ({required String verificationId, required String smsCode}) async {
              throw const AuthException('Code de vérification invalide');
            },
      );
      final ProviderContainer container = makeContainer(gateway);
      addTearDown(container.dispose);

      final LoginNotifier notifier = container.read(loginProvider.notifier);
      notifier.setIdentifier('0700000000');
      await notifier.submit();

      final bool verified = await notifier.verifyPhoneOtp('000000');

      expect(verified, isFalse);
      final LoginState state = container.read(loginProvider);
      expect(state.errorMessage, 'Code de vérification invalide');
      expect(state.otpRequested, isTrue);
      expect(state.success, isFalse);
    },
  );

  test('resends a new phone verification code', () async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.setIdentifier('0700000000');
    await notifier.submit();
    expect(gateway.sendPhoneCodeCalls, 1);

    final bool sent = await notifier.resendPhoneOtp();

    expect(sent, isTrue);
    expect(gateway.sendPhoneCodeCalls, 2);
    expect(container.read(loginProvider).otpRequested, isTrue);
  });

  test('exposes the French message when credentials are invalid', () async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: ({required String email, required String password}) async {
        throw const AuthException('Identifiants invalides');
      },
    );
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.toggleIdentifierMode();
    notifier.setIdentifier('david@example.com');
    notifier.setPassword('wrong-password');

    await notifier.submit();

    final LoginState state = container.read(loginProvider);
    expect(state.errorMessage, 'Identifiants invalides');
    expect(state.success, isFalse);
  });

  test('falls back to a generic message for unknown errors', () async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: ({required String email, required String password}) async {
        throw StateError('boom');
      },
    );
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.toggleIdentifierMode();
    notifier.setIdentifier('david@example.com');
    notifier.setPassword('password123');

    await notifier.submit();

    final LoginState state = container.read(loginProvider);
    expect(state.errorMessage, "Une erreur est survenue, réessayez");
  });

  test('flips isSubmitting while the request is in flight', () async {
    final Completer<void> completer = Completer<void>();
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: ({required String email, required String password}) =>
          completer.future,
    );
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.toggleIdentifierMode();
    notifier.setIdentifier('david@example.com');
    notifier.setPassword('password123');

    final Future<void> submission = notifier.submit();
    expect(container.read(loginProvider).isSubmitting, isTrue);

    completer.complete();
    await submission;

    expect(container.read(loginProvider).isSubmitting, isFalse);
  });

  test('clearSubmissionResult resets the outcome fields', () async {
    final ProviderContainer container = makeContainer(FakeAuthGateway());
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.toggleIdentifierMode();
    notifier.setIdentifier('david@example.com');
    notifier.setPassword('password123');
    await notifier.submit();

    expect(container.read(loginProvider).success, isTrue);

    notifier.clearSubmissionResult();

    final LoginState state = container.read(loginProvider);
    expect(state.success, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.successMessage, isNull);
  });
}
