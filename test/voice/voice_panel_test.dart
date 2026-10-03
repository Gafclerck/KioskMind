import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/localization/generated/app_localizations.dart';
import 'package:kiosk_mind/core/voice_services/speech_recognizer_port.dart';
import 'package:kiosk_mind/features/voice_assistant/di/voice_dependencies.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_panel.dart';

import 'fake_clock.dart';
import 'fake_speech_services.dart';

/// The panel of a session whose microphone and voice are fakes.
///
/// Only the two device services are replaced, and the whole composition root is
/// built around them: what the merchant reads and hears here is produced by the
/// same session, the same parser and the same handlers as in the app. The clock is
/// a fake as well, so a window that closes in ten seconds closes when the test says
/// so and not ten seconds later.
class PanelHarness {
  PanelHarness({SpeechReadiness readiness = SpeechReadiness.ready})
    : recognizer = FakeSpeechRecognizer(readiness: readiness),
      clock = FakeClock(DateTime(2026, 3, 14, 9, 30));

  final FakeSpeechRecognizer recognizer;
  final FakeTts tts = FakeTts();
  final FakeClock clock;

  /// Mounts the panel over the composition root, with the devices faked.
  ///
  /// The two files the root reads are read in the real zone on purpose: a widget
  /// test runs on a fake clock and an asset read started there never finishes, so
  /// a session that loaded them itself would hang on its first turn. Everything
  /// built from those two files is the real thing.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          voiceRecognizerProvider.overrideWith((Ref ref) async => recognizer),
          voiceTtsProvider.overrideWithValue(tts),
          voiceClockProvider.overrideWithValue(clock),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VoicePanel()),
        ),
      ),
    );
    await flush(tester);
    await tester.runAsync(() async {
      final ProviderContainer container = containerOf(tester);
      await container.read(voiceMockCatalogProvider.future);
      await container.read(voiceIntentsProvider.future);
    });
    await flush(tester);
  }

  /// The journal of the container the panel is mounted in.
  HandlerCallJournal journalOf(WidgetTester tester) =>
      containerOf(tester).read(voiceCallJournalProvider);

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(VoicePanel)));

  /// The ids of the use cases that ran, in order.
  List<String> intentsCalled(WidgetTester tester) =>
      journalOf(tester).calls.map((HandlerCall call) => call.intentId).toList();
}

/// Lets the session finish what it started.
///
/// A turn is a chain of futures: the microphone, the composition root, the policy
/// and the handler each answer in turn, and one frame is not enough to see the last
/// one. Nothing here waits for real time: each round hands a turn to the real zone
/// so the promises the session is waiting on can land, then pumps a frame.
Future<void> flush(WidgetTester tester) async {
  for (int frame = 0; frame < 8; frame++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  group('an idle panel', () {
    testWidgets('says what to do and offers a microphone', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);

      expect(
        find.text('Touchez le micro et dites votre commande'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.text('Annuler'), findsNothing);
    });

    testWidgets('opens the microphone when it is pressed', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);

      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);

      expect(harness.recognizer.listenCount, 1);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('shows what is heard while the merchant talks', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);

      harness.recognizer.hear('vendu deux sa');
      await flush(tester);

      expect(find.text('Entendu: vendu deux sa'), findsOneWidget);
    });
  });

  group('a command that runs', () {
    testWidgets('shows the recap, says it, and offers to take it back', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);

      harness.recognizer.hearFinal('vendu deux savon');
      await flush(tester);

      expect(find.textContaining('ligne enregistrée'), findsOneWidget);
      expect(find.textContaining('Savon de ménage'), findsOneWidget);
      expect(find.textContaining('cinq cents francs'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(harness.tts.lastSpoken, contains('Savon de ménage'));
      expect(harness.tts.lastSpoken, contains('cinq cents francs'));
      expect(harness.intentsCalled(tester), <String>['record_sale']);
    });

    testWidgets('the undo banner closes with its window', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);
      harness.recognizer.hearFinal('vendu deux savon');
      await flush(tester);
      expect(find.text('Annuler'), findsOneWidget);

      harness.clock.elapse(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Annuler'), findsNothing);
    });

    testWidgets('undo takes the sale back and says so', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);
      harness.recognizer.hearFinal('vendu deux savon');
      await flush(tester);

      await tester.tap(find.text('Annuler'));
      await flush(tester);

      expect(find.text('Vente annulée'), findsOneWidget);
      expect(harness.intentsCalled(tester), <String>[
        'record_sale',
        'cancel_last_sale',
      ]);
    });
  });

  group('a question', () {
    testWidgets('is asked on screen and spoken', (WidgetTester tester) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);

      harness.recognizer.hearFinal('vendu du sucre');
      await flush(tester);

      expect(find.text('Combien ?'), findsOneWidget);
      expect(harness.tts.lastSpoken, 'Combien ?');
      expect(harness.intentsCalled(tester), isEmpty);
    });

    testWidgets('is settled by the answer the merchant speaks', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);
      harness.recognizer.hearFinal('vendu du sucre');
      await flush(tester);

      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);
      harness.recognizer.hearFinal('deux');
      await flush(tester);

      expect(harness.intentsCalled(tester), <String>['record_sale']);
    });

    testWidgets('an ambiguous name offers the products it could mean', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);

      harness.recognizer.hearFinal('vendu deux huiles');
      await flush(tester);

      expect(find.text('Lequel ?'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Huile végétale'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Huile de palme'),
        findsOneWidget,
      );
    });

    testWidgets('pointing at one of them completes the command', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);
      harness.recognizer.hearFinal('vendu deux huiles');
      await flush(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Huile de palme'));
      await flush(tester);

      expect(
        harness.journalOf(tester).calls.single.handlerArgs['items'],
        <Object?>[
          <String, Object?>{'productId': 'p_huile_palme', 'qty': 2},
        ],
      );
    });

    testWidgets('a confirmation offers a yes and a no', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);

      harness.recognizer.hearFinal('vendu trente sucre');
      await flush(tester);

      expect(find.text('Vous confirmez ?'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Oui'), findsOneWidget);
      expect(find.text('Non'), findsOneWidget);
      expect(harness.intentsCalled(tester), isEmpty);
    });

    testWidgets('a yes runs the sale that was waiting', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);
      harness.recognizer.hearFinal('vendu trente sucre');
      await flush(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Oui'));
      await flush(tester);

      expect(
        harness.journalOf(tester).calls.single.handlerArgs['items'],
        <Object?>[
          <String, Object?>{'productId': 'p_sucre', 'qty': 30},
        ],
      );
    });

    testWidgets('a no asks again and runs nothing', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);
      harness.recognizer.hearFinal('vendu trente sucre');
      await flush(tester);

      await tester.tap(find.text('Non'));
      await flush(tester);

      expect(find.text('Vous confirmez ?'), findsOneWidget);
      expect(harness.intentsCalled(tester), isEmpty);
    });

    testWidgets('a question nobody answers ends on the screens', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);
      harness.recognizer.hearFinal('vendu du sucre');
      await flush(tester);

      harness.clock.elapse(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Saisie manuelle'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);
    });
  });

  group('a microphone that cannot be used', () {
    testWidgets('offers the manual route and the way back', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness(
        readiness: SpeechReadiness.permissionDenied,
      );
      await harness.pump(tester);

      await tester.tap(find.byIcon(Icons.mic_none));
      await flush(tester);

      expect(find.text('Saisie manuelle'), findsOneWidget);
      expect(find.text('Revenir à la voix'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(harness.tts.lastSpoken, contains('Micro autorisé'));

      await tester.tap(find.text('Revenir à la voix'));
      await flush(tester);

      expect(find.text('Saisie manuelle'), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });
  });
}
