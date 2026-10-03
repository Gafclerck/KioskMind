import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/localization/generated/app_localizations.dart';
import 'package:kiosk_mind/features/voice_assistant/di/voice_dependencies.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_session_sheet.dart';

import 'fake_clock.dart';
import 'fake_speech_services.dart';

void main() {
  test('the till chrome opens the voice session, not a snackbar', () {
    final String source = File(
      'lib/features/navigation/main_navigation_page.dart',
    ).readAsStringSync();

    expect(source, contains('openVoiceSession'));
    expect(source.contains('Assistant vocal'), isFalse);
    expect(source.contains('SnackBar'), isFalse);
  });

  testWidgets('opening the session shows the panel and starts listening', (
    WidgetTester tester,
  ) async {
    final FakeSpeechRecognizer recognizer = FakeSpeechRecognizer();
    await _pumpLauncher(tester, recognizer: recognizer);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await flush(tester);

    expect(
      find.text('Touchez le micro et dites votre commande'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(recognizer.listenCount, 1);
  });

  testWidgets('closing the sheet stops the microphone', (
    WidgetTester tester,
  ) async {
    final FakeSpeechRecognizer recognizer = FakeSpeechRecognizer();
    await _pumpLauncher(tester, recognizer: recognizer);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await flush(tester);
    expect(recognizer.listenCount, 1);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await flush(tester);

    expect(recognizer.stopCount, greaterThan(0));
    expect(find.text('Touchez le micro et dites votre commande'), findsNothing);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required FakeSpeechRecognizer recognizer,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        voiceRecognizerProvider.overrideWith((Ref ref) async => recognizer),
        voiceTtsProvider.overrideWithValue(FakeTts()),
        voiceClockProvider.overrideWithValue(
          FakeClock(DateTime(2026, 3, 14, 9, 30)),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: () => openVoiceSession(context),
                child: const Icon(Icons.mic_rounded),
              ),
            );
          },
        ),
      ),
    ),
  );
  await flush(tester);
  await tester.runAsync(() async {
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(FloatingActionButton)),
    );
    await container.read(voiceMockCatalogProvider.future);
    await container.read(voiceIntentsProvider.future);
  });
  await flush(tester);
}

Future<void> flush(WidgetTester tester) async {
  for (int frame = 0; frame < 8; frame++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}
