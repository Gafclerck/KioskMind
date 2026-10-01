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
    'resolves the email from a normalized +225 phone and signs in',
    () async {
      final FakeAuthGateway gateway = FakeAuthGateway()
        ..registerPhone('+2250700000000', 'david@example.com');
      final ProviderContainer container = makeContainer(gateway);
      addTearDown(container.dispose);

      final LoginNotifier notifier = container.read(loginProvider.notifier);
      notifier.setIdentifier('07 00 00 00 00');
      notifier.setPassword('password123');

      await notifier.submit();

      expect(gateway.phoneSearchCalls, 1);
      expect(gateway.lastPhoneSearchNumber, '+2250700000000');
      expect(gateway.signInCalls, 1);
      expect(gateway.lastSignInEmail, 'david@example.com');
      final LoginState state = container.read(loginProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.success, isTrue);
      expect(state.successMessage, 'Connexion réussie');
    },
  );

  test('does not sign in when the phone number is unknown', () async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.setIdentifier('0700000000');
    notifier.setPassword('password123');

    await notifier.submit();

    expect(gateway.phoneSearchCalls, 1);
    expect(gateway.signInCalls, 0);
    final LoginState state = container.read(loginProvider);
    expect(
      state.errorMessage,
      'Aucun compte n\'est associé à ce numéro de téléphone. '
      'Veuillez vous inscrire.',
    );
    expect(state.success, isFalse);
  });

  test(
    'signs in with the password of the email resolved from the phone',
    () async {
      final FakeAuthGateway gateway = FakeAuthGateway(
        onSignIn: ({required String email, required String password}) async {
          if (password != 'password123') {
            throw const AuthException('Mot de passe incorrect');
          }
        },
      )..registerPhone('+2250700000000', 'david@example.com');
      final ProviderContainer container = makeContainer(gateway);
      addTearDown(container.dispose);

      final LoginNotifier notifier = container.read(loginProvider.notifier);
      notifier.setIdentifier('0700000000');
      notifier.setPassword('wrong-password');

      await notifier.submit();

      final LoginState state = container.read(loginProvider);
      expect(gateway.signInCalls, 1);
      expect(gateway.lastSignInEmail, 'david@example.com');
      expect(state.errorMessage, 'Mot de passe incorrect');
      expect(state.success, isFalse);
    },
  );

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
