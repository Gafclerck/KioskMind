import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/core/theme/app_theme.dart';
import 'package:kiosk_mind/features/auth/presentation/pages/signup_page.dart';

Future<void> pumpSignup(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.lightTheme, home: SignupPage()),
    ),
  );
  await tester.pump();
}

Finder fullNameField() => find.byType(TextFormField).at(0);

Finder phoneField() => find.byType(TextFormField).at(1);

Finder passwordField() => find.byType(TextFormField).at(2);

Finder confirmationField() => find.byType(TextFormField).at(3);

void main() {
  testWidgets('renders the form with every section', (tester) async {
    await pumpSignup(tester);

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Nom complet'), findsOneWidget);
    expect(find.text('Indicatif'), findsOneWidget);
    expect(find.text('+225'), findsOneWidget);
    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(find.text("S'inscrire avec Google"), findsOneWidget);
    expect(find.text('Déjà un compte ?'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('shows validation errors on empty submit', (tester) async {
    await pumpSignup(tester);

    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    expect(find.text('Nom complet requis'), findsOneWidget);
    expect(find.text('Saisissez votre numéro de téléphone'), findsOneWidget);
    expect(find.text('Saisissez votre mot de passe'), findsOneWidget);
    expect(find.text('Confirmez votre mot de passe'), findsOneWidget);
    expect(find.text('Vous devez accepter les conditions'), findsOneWidget);
  });

  testWidgets('requires first and last name', (tester) async {
    await pumpSignup(tester);

    await tester.enterText(fullNameField(), 'David');
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    expect(find.text('Saisissez votre nom et votre prénom'), findsOneWidget);
  });

  testWidgets('rejects mismatched password confirmations', (tester) async {
    await pumpSignup(tester);

    await tester.enterText(passwordField(), 'password123');
    await tester.enterText(confirmationField(), 'password456');
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
  });

  testWidgets('submits a fully valid form when terms are accepted', (
    tester,
  ) async {
    await pumpSignup(tester);

    await tester.enterText(fullNameField(), 'David Koné');
    await tester.enterText(phoneField(), '0700000000');
    await tester.enterText(passwordField(), 'password123');
    await tester.enterText(confirmationField(), 'password123');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();

    expect(find.text('Inscription bientôt disponible'), findsOneWidget);
    expect(find.text('Vous devez accepter les conditions'), findsNothing);
  });

  testWidgets('toggles both password visibility icons', (tester) async {
    await pumpSignup(tester);

    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(1));
  });
}
