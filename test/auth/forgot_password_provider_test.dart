import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/auth/domain/auth_gateway.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_gateway_provider.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/forgot_password_provider.dart';

import 'fakes.dart';

ProviderContainer makeContainer(FakeAuthGateway gateway) {
  return ProviderContainer(
    overrides: [authGatewayProvider.overrideWithValue(gateway)],
  );
}

void main() {
  test('starts empty and idle', () {
    final ProviderContainer container = makeContainer(FakeAuthGateway());
    addTearDown(container.dispose);

    final ForgotPasswordState state = container.read(forgotPasswordProvider);
    expect(state.email, isEmpty);
    expect(state.isSubmitting, isFalse);
    expect(state.succeeded, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('sends the reset link email on success', () async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final ForgotPasswordNotifier notifier = container.read(
      forgotPasswordProvider.notifier,
    );
    notifier.setEmail('  david@example.com  ');
    final ForgotPasswordState result = await notifier.send();

    expect(gateway.sendResetCalls, 1);
    expect(gateway.lastResetEmail, 'david@example.com');
    expect(result.succeeded, isTrue);
    expect(result.errorMessage, isNull);
  });

  test('exposes the French message when the reset fails', () async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSendReset: ({required String email}) async {
        throw const AuthException(
          'Aucun compte associé à cette adresse e-mail',
        );
      },
    );
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final ForgotPasswordNotifier notifier = container.read(
      forgotPasswordProvider.notifier,
    );
    notifier.setEmail('inconnu@example.com');
    final ForgotPasswordState result = await notifier.send();

    expect(result.succeeded, isFalse);
    expect(result.errorMessage, 'Aucun compte associé à cette adresse e-mail');
  });

  test('falls back to a generic message for unknown errors', () async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSendReset: ({required String email}) async {
        throw StateError('boom');
      },
    );
    final ProviderContainer container = makeContainer(gateway);
    addTearDown(container.dispose);

    final ForgotPasswordNotifier notifier = container.read(
      forgotPasswordProvider.notifier,
    );
    notifier.setEmail('david@example.com');
    final ForgotPasswordState result = await notifier.send();

    expect(result.errorMessage, "Une erreur est survenue, réessayez");
  });

  test('reset restores the initial state', () async {
    final ProviderContainer container = makeContainer(FakeAuthGateway());
    addTearDown(container.dispose);

    final ForgotPasswordNotifier notifier = container.read(
      forgotPasswordProvider.notifier,
    );
    notifier.setEmail('david@example.com');
    await notifier.send();
    expect(container.read(forgotPasswordProvider).succeeded, isTrue);

    notifier.reset();

    final ForgotPasswordState state = container.read(forgotPasswordProvider);
    expect(state.email, isEmpty);
    expect(state.succeeded, isFalse);
    expect(state.errorMessage, isNull);
  });
}
