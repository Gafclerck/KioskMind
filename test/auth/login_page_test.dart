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

  testWidgets('phone submit announces that OTP arrives in Phase B', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    await pumpLogin(tester, gateway: gateway);

    await tester.enterText(loginField(), '0700000000');
    await tester.enterText(passwordField(), 'password123');
    await tapSubmit(tester);

    expect(gateway.signInCalls, 0);
    expect(
      find.text('La connexion par téléphone (OTP) arrivera en Phase B'),
      findsOneWidget,
    );
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
}
