import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/core/theme/app_theme.dart';
import 'package:kiosk_mind/core/widgets/app_toast.dart';
import 'package:kiosk_mind/features/auth/domain/auth_gateway.dart';
import 'package:kiosk_mind/features/auth/presentation/pages/login_page.dart';
import 'package:kiosk_mind/features/auth/presentation/pages/signup_page.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_gateway_provider.dart';

import 'fakes.dart';

Future<void> pumpLogin(WidgetTester tester, {FakeAuthGateway? gateway}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(gateway ?? FakeAuthGateway()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (BuildContext context, Widget? child) {
          return AppToastHost(child: child ?? const SizedBox.shrink());
        },
        home: LoginPage(),
      ),
    ),
  );
  await tester.pump();
}

Finder loginField() => find.byType(TextFormField).first;

Finder passwordField() => find.byType(TextFormField).at(1);

Future<void> switchToEmailMode(WidgetTester tester) async {
  await tester.tap(find.text('Utiliser l\'e-mail'));
  await tester.pumpAndSettle();
}

Future<void> tapSubmit(WidgetTester tester) async {
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle();
}

Finder dialogEmailField() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextFormField),
);

void main() {
  testWidgets('renders the header and phone-first fields', (tester) async {
    await pumpLogin(tester);

    expect(find.text('Bon retour !'), findsOneWidget);
    expect(
      find.text('Connectez-vous à votre copilote KioskMind'),
      findsOneWidget,
    );
    expect(find.text('Numéro de téléphone'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Pas encore de compte ?'), findsOneWidget);
    expect(find.text("S'inscrire"), findsOneWidget);
  });

  testWidgets('toggles between phone and email modes', (tester) async {
    await pumpLogin(tester);

    expect(find.text('Utiliser l\'e-mail'), findsOneWidget);

    await switchToEmailMode(tester);

    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Utiliser le téléphone'), findsOneWidget);
  });

  testWidgets('toggles password visibility', (tester) async {
    await pumpLogin(tester);

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
  });

  testWidgets('shows validation errors on empty submit', (tester) async {
    await pumpLogin(tester);

    await tapSubmit(tester);

    expect(find.text('Saisissez votre numéro de téléphone'), findsOneWidget);
    expect(find.text('Saisissez votre mot de passe'), findsOneWidget);
  });

  testWidgets('rejects an invalid phone number', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(loginField(), 'abc');
    await tapSubmit(tester);

    expect(find.text('Numéro invalide (8 à 15 chiffres)'), findsOneWidget);
  });

  testWidgets('phone submit resolves the email and shows the confirmation', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway()
      ..registerPhone('+2250700000000', 'david@example.com');
    await pumpLogin(tester, gateway: gateway);

    await tester.enterText(loginField(), '0700000000');
    await tester.enterText(passwordField(), 'password123');
    await tapSubmit(tester);

    expect(gateway.phoneSearchCalls, 1);
    expect(gateway.lastPhoneSearchNumber, '+2250700000000');
    expect(gateway.signInCalls, 1);
    expect(gateway.lastSignInEmail, 'david@example.com');
    expect(find.text('Connexion réussie'), findsOneWidget);
  });

  testWidgets('phone submit shows a toast when the number is unknown', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    await pumpLogin(tester, gateway: gateway);

    await tester.enterText(loginField(), '0700000000');
    await tester.enterText(passwordField(), 'password123');
    await tapSubmit(tester);

    expect(gateway.signInCalls, 0);
    expect(
      find.text(
        'Aucun compte n\'est associé à ce numéro de téléphone. '
        'Veuillez vous inscrire.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('phone submit shows a toast when the password is wrong', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: ({required String email, required String password}) async {
        throw const AuthException('Mot de passe incorrect');
      },
    )..registerPhone('+2250700000000', 'david@example.com');
    await pumpLogin(tester, gateway: gateway);

    await tester.enterText(loginField(), '0700000000');
    await tester.enterText(passwordField(), 'wrong-password');
    await tapSubmit(tester);

    expect(gateway.signInCalls, 1);
    expect(gateway.lastSignInEmail, 'david@example.com');
    expect(find.text('Mot de passe incorrect'), findsOneWidget);
  });

  testWidgets('submits a valid email form and shows a confirmation toast', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    await pumpLogin(tester, gateway: gateway);

    await switchToEmailMode(tester);
    await tester.enterText(loginField(), 'david@example.com');
    await tester.enterText(passwordField(), 'password123');
    await tapSubmit(tester);

    expect(gateway.signInCalls, 1);
    expect(gateway.lastSignInEmail, 'david@example.com');
    expect(find.text('Connexion réussie'), findsOneWidget);
  });

  testWidgets('shows the French error message when login fails', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: ({required String email, required String password}) async {
        throw const AuthException('Identifiants invalides');
      },
    );
    await pumpLogin(tester, gateway: gateway);

    await switchToEmailMode(tester);
    await tester.enterText(loginField(), 'david@example.com');
    await tester.enterText(passwordField(), 'password123');
    await tapSubmit(tester);

    expect(find.text('Identifiants invalides'), findsOneWidget);
  });

  testWidgets('disables the button while submitting', (tester) async {
    final Completer<void> completer = Completer<void>();
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: ({required String email, required String password}) =>
          completer.future,
    );
    await pumpLogin(tester, gateway: gateway);

    await switchToEmailMode(tester);
    await tester.enterText(loginField(), 'david@example.com');
    await tester.enterText(passwordField(), 'password123');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('navigates to the signup page', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.byType(SignupPage), findsOneWidget);
  });

  testWidgets('forgot password shows the dialog and rejects an invalid email', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    await pumpLogin(tester, gateway: gateway);

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();

    expect(find.text('Réinitialiser le mot de passe'), findsOneWidget);

    await tester.enterText(dialogEmailField(), 'pas-un-email');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse e-mail invalide'), findsOneWidget);
    expect(gateway.sendResetCalls, 0);
  });

  testWidgets('forgot password sends the reset link and dismisses on success', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    await pumpLogin(tester, gateway: gateway);

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();

    await tester.enterText(dialogEmailField(), 'david@example.com');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(gateway.sendResetCalls, 1);
    expect(gateway.lastResetEmail, 'david@example.com');
    expect(find.text('Réinitialiser le mot de passe'), findsNothing);
    expect(find.text('Lien de réinitialisation envoyé'), findsOneWidget);
  });

  testWidgets('forgot password surfaces the French error inline', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSendReset: ({required String email}) async {
        throw const AuthException(
          'Aucun compte associé à cette adresse e-mail',
        );
      },
    );
    await pumpLogin(tester, gateway: gateway);

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();

    await tester.enterText(dialogEmailField(), 'inconnu@example.com');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Aucun compte associé à cette adresse e-mail'),
      findsOneWidget,
    );
    expect(find.text('Réinitialiser le mot de passe'), findsOneWidget);
  });
}
