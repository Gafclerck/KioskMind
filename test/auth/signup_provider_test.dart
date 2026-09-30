import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/auth/domain/auth_gateway.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_gateway_provider.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/signup_provider.dart';

import 'fakes.dart';

ProviderContainer makeContainer(FakeAuthGateway gateway) {
  return ProviderContainer(
    overrides: [authGatewayProvider.overrideWithValue(gateway)],
  );
}

SignupNotifier fillProfile(ProviderContainer container) {
  final SignupNotifier notifier = container.read(signupProvider.notifier);
  notifier.setFullName('David Koné');
  notifier.setPhone('0700000000');
  notifier.setEmail('david@example.com');
  notifier.setPassword('password123');
  notifier.setAcceptedTerms(true);
  return notifier;
}

void main() {
  test('starts with the default country code and empty fields', () {
    final ProviderContainer container = makeContainer(FakeAuthGateway());
    addTearDown(container.dispose);

    final SignupState state = container.read(signupProvider);
    expect(state.countryCode, '+225');
    expect(state.fullName, isEmpty);
    expect(state.phone, isEmpty);
    expect(state.email, isEmpty);
    expect(state.password, isEmpty);
    expect(state.acceptedTerms, isFalse);
    expect(state.isSubmitting, isFalse);
    expect(state.success, isFalse);
  });

  test('submits and signs up with the profile fields', () async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final SignupNotifier notifier = fillProfile(container);
    await notifier.submit();

    final SignupState state = container.read(signupProvider);
    expect(gateway.signUpCalls, 1);
    expect(gateway.lastSignUpEmail, 'david@example.com');
    expect(state.isSubmitting, isFalse);
    expect(state.success, isTrue);
  });

  test('exposes the French message when the email is already in use', () async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignUp:
          ({
            required String fullName,
            required String phone,
            required String countryCode,
            required String email,
            required String password,
          }) async {
            throw const AuthException('Cette adresse e-mail est déjà utilisée');
          },
    );
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final SignupNotifier notifier = fillProfile(container);
    await notifier.submit();

    final SignupState state = container.read(signupProvider);
    expect(state.errorMessage, 'Cette adresse e-mail est déjà utilisée');
    expect(state.success, isFalse);
  });

  test('falls back to a generic message for unknown errors', () async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignUp:
          ({
            required String fullName,
            required String phone,
            required String countryCode,
            required String email,
            required String password,
          }) async {
            throw StateError('boom');
          },
    );
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final SignupNotifier notifier = fillProfile(container);
    await notifier.submit();

    final SignupState state = container.read(signupProvider);
    expect(state.errorMessage, "Une erreur est survenue, réessayez");
  });

  test('flips isSubmitting while the request is in flight', () async {
    final Completer<void> completer = Completer<void>();
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignUp:
          ({
            required String fullName,
            required String phone,
            required String countryCode,
            required String email,
            required String password,
          }) => completer.future,
    );
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final SignupNotifier notifier = fillProfile(container);
    final Future<void> submission = notifier.submit();
    expect(container.read(signupProvider).isSubmitting, isTrue);

    completer.complete();
    await submission;

    expect(container.read(signupProvider).isSubmitting, isFalse);
  });

  test('clearSubmissionResult resets the outcome fields', () async {
    final ProviderContainer container = makeContainer(FakeAuthGateway());
    addTearDown(container.dispose);

    final SignupNotifier notifier = fillProfile(container);
    await notifier.submit();

    expect(container.read(signupProvider).success, isTrue);

    notifier.clearSubmissionResult();

    final SignupState state = container.read(signupProvider);
    expect(state.success, isFalse);
    expect(state.errorMessage, isNull);
  });
}
