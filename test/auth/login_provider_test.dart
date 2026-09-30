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
    expect(state.notice, isNull);
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

  test('keeps interface untouched for phone and announces Phase B', () async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final LoginNotifier notifier = container.read(loginProvider.notifier);
    notifier.setIdentifier('0700000000');
    notifier.setPassword('password123');

    await notifier.submit();

    final LoginState state = container.read(loginProvider);
    expect(gateway.signInCalls, 0);
    expect(
      state.notice,
      'La connexion par téléphone (OTP) arrivera en Phase B',
    );
    expect(state.success, isFalse);
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
    expect(state.notice, isNull);
  });
}
