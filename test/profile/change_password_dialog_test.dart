import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/theme/app_theme.dart';
import 'package:kiosk_mind/features/auth/domain/auth_gateway.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_gateway_provider.dart';
import 'package:kiosk_mind/features/settings/presentation/widgets/change_password_dialog.dart';

import '../auth/fakes.dart';

Future<void> pumpDialog(WidgetTester tester, FakeAuthGateway gateway) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            return Scaffold(
              body: Center(
                child: Builder(
                  builder: (BuildContext innerContext) {
                    return FilledButton(
                      onPressed: () =>
                          showChangePasswordDialog(innerContext, ref),
                      child: const Text('Ouvrir'),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rejects invalid passwords with validation messages', (
    tester,
  ) async {
    await pumpDialog(tester, FakeAuthGateway());

    expect(find.text('Changer le mot de passe'), findsOneWidget);
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();

    expect(find.text('Saisissez votre mot de passe'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'court');
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();
    expect(find.text('8 caractères minimum'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'nouveau12345');
    await tester.enterText(find.byType(TextField).at(2), 'different123');
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();
    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
  });

  testWidgets('calls changePassword and closes the dialog on success', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    await pumpDialog(tester, gateway);

    await tester.enterText(find.byType(TextField).at(0), 'actuel123');
    await tester.enterText(find.byType(TextField).at(1), 'nouveau12345');
    await tester.enterText(find.byType(TextField).at(2), 'nouveau12345');
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();

    expect(gateway.changePasswordCalls, 1);
    expect(gateway.lastCurrentPassword, 'actuel123');
    expect(gateway.lastNewPassword, 'nouveau12345');
    expect(find.byType(ChangePasswordDialog), findsNothing);
  });

  testWidgets('shows the AuthException message and keeps the dialog open', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onChangePassword:
          ({
            required String currentPassword,
            required String newPassword,
          }) async {
            throw AuthException('Mot de passe actuel incorrect');
          },
    );
    await pumpDialog(tester, gateway);

    await tester.enterText(find.byType(TextField).at(0), 'mauvais');
    await tester.enterText(find.byType(TextField).at(1), 'nouveau12345');
    await tester.enterText(find.byType(TextField).at(2), 'nouveau12345');
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();

    expect(find.text('Mot de passe actuel incorrect'), findsOneWidget);
    expect(find.byType(ChangePasswordDialog), findsOneWidget);
  });
}
