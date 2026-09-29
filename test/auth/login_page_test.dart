import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/core/theme/app_theme.dart';
import 'package:kiosk_mind/features/auth/presentation/pages/login_page.dart';
import 'package:kiosk_mind/features/auth/presentation/pages/signup_page.dart';

Future<void> pumpLogin(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.lightTheme, home: LoginPage()),
    ),
  );
  await tester.pump();
}

Finder loginField() => find.byType(TextFormField).first;

Finder passwordField() => find.byType(TextFormField).at(1);

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

    await tester.tap(find.text('Utiliser l\'e-mail'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Saisissez votre numéro de téléphone'), findsOneWidget);
    expect(find.text('Saisissez votre mot de passe'), findsOneWidget);
  });

  testWidgets('rejects an invalid phone number', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(loginField(), 'abc');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Numéro invalide (8 à 15 chiffres)'), findsOneWidget);
  });

  testWidgets('submits a valid form and shows a confirmation snackbar', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.enterText(loginField(), '0700000000');
    await tester.enterText(passwordField(), 'password123');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Connexion bientôt disponible'), findsOneWidget);
  });

  testWidgets('navigates to the signup page', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.byType(SignupPage), findsOneWidget);
  });
}
