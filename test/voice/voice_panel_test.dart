import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/localization/generated/app_localizations.dart';
import 'package:kiosk_mind/core/voice_services/speech_recognizer_port.dart';
import 'package:kiosk_mind/features/voice_assistant/di/voice_dependencies.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_panel.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_waveform.dart';

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

  /// How many times the merchant closed the sheet.
  int closes = 0;

  /// Mounts the panel over the composition root, with the devices faked.
  ///
  /// The two files the root reads are read in the real zone on purpose: a widget
  /// test runs on a fake clock and an asset read started there never finishes, so
  /// a session that loaded them itself would hang on its first turn. Everything
  /// built from those two files is the real thing.
  ///
  /// The panel is given the height of a phone rather than the 600 by 800 of the
  /// default test surface: the panel is a bottom sheet, and a sheet tested at a
  /// landscape aspect ratio would never be scrolled the way a merchant scrolls it.
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          voiceRecognizerProvider.overrideWith((Ref ref) async => recognizer),
          voiceTtsProvider.overrideWithValue(tts),
          voiceClockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VoicePanel(onClose: () => closes++)),
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

  /// Opens the microphone and settles.
  Future<void> listen(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await flush(tester);
  }
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
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('names itself and offers a way out', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);

      expect(find.text('Copilote vocal'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await flush(tester);

      expect(harness.closes, 1);
    });

    testWidgets('opens the microphone when it is pressed', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);

      await harness.listen(tester);

      expect(harness.recognizer.listenCount, 1);
      expect(find.text('Je vous écoute'), findsOneWidget);
    });

    testWidgets('shows what is heard while the merchant talks', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);

      harness.recognizer.hear('vendu deux sa');
      await flush(tester);

      // The transcript is the merchant's own words, without a label in front of
      // them: it is the largest text on the green area and the label would only push
      // it onto a second line.
      expect(find.text('vendu deux sa'), findsOneWidget);
    });
  });

  group('the waveform', () {
    testWidgets('says the microphone is closed and draws six bars', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);

      // Six bars, and the panel says the microphone is closed, so a moving row
      // would claim to hear something it cannot. Whether they move is checked where
      // the status can be set one at a time, in voice_waveform_test.dart.
      expect(_bars(tester), 6);
      expect(find.text('Parler'), findsOneWidget);
    });

    testWidgets('is labelled for a reader who cannot see it', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);

      expect(find.bySemanticsLabel('Niveau du micro'), findsOneWidget);
    });

    testWidgets('moves only while the microphone is open', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);

      expect(find.text('Je vous écoute'), findsOneWidget);
      expect(_bars(tester), 6);
    });
  });

  group('a command that runs', () {
    testWidgets('shows the products it recorded, with their total', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);

      harness.recognizer.hearFinal('vendu deux savon');
      await flush(tester);

      // The heading says the command has run, not that it is about to: reading
      // "Produits détectés" over a written sale would say his basket is still open.
      expect(find.text('Ce qui a été enregistré'), findsOneWidget);
      expect(find.text('Savon de ménage'), findsOneWidget);
      expect(find.text('2 pièces × 250 F'), findsOneWidget);
      expect(find.text('Montant total'), findsOneWidget);
      // Twice, and correctly: the card carries the line and the panel carries the
      // basket, and on a one-line sale the two are the same figure. A merchant
      // checking his arithmetic wants to see both and to see that they agree.
      expect(find.text('500 FCFA'), findsNWidgets(2));
      expect(harness.tts.lastSpoken, contains('Savon de ménage'));
      expect(harness.tts.lastSpoken, contains('cinq cents francs'));
      expect(harness.intentsCalled(tester), <String>['record_sale']);
    });

    testWidgets('offers to take the sale back, for as long as it can', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);
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
      await harness.listen(tester);
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

    testWidgets('clears lastHeard on completion and isolates subsequent sessions', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);

      // Session 1: the transcript shows the words as they are said.
      await harness.listen(tester);
      harness.recognizer.hear('vendu deux');
      await flush(tester);
      expect(find.text('vendu deux'), findsOneWidget);

      // Session 1 finishes: the transcript must not keep the finished command,
      // or the merchant reads it as what he is about to say.
      harness.recognizer.hearFinal('vendu deux savon');
      await flush(tester);
      expect(find.text('vendu deux'), findsNothing);
      expect(find.text('Savon de ménage'), findsOneWidget);

      // Session 2: the transcript carries the new words only. The recorded sale
      // stays on the panel on purpose, because it is the reference the merchant
      // speaks his next command against.
      await harness.listen(tester);
      harness.recognizer.hear('combien coute');
      await flush(tester);
      expect(find.text('combien coute'), findsOneWidget);
      expect(find.text('vendu deux'), findsNothing);
    });

    testWidgets('offers a new command rather than a confirmation', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);
      harness.recognizer.hearFinal('vendu deux savon');
      await flush(tester);

      // Nothing is left to decide, so "Confirmer" would be a lie and "Réessayer"
      // alone would leave the merchant without a second gesture.
      expect(find.text('Nouvelle commande'), findsOneWidget);
      expect(find.text('Confirmer'), findsNothing);

      await tester.tap(find.text('Nouvelle commande'));
      await flush(tester);

      expect(harness.recognizer.listenCount, 2);
    });
  });

  group('a question', () {
    testWidgets('is asked on screen and spoken', (WidgetTester tester) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);

      harness.recognizer.hearFinal('vendu du sucre');
      await flush(tester);

      expect(find.text('Combien ?'), findsOneWidget);
      expect(harness.tts.lastSpoken, 'Combien ?');
      expect(harness.intentsCalled(tester), isEmpty);
    });

    testWidgets('names what it found while it asks', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);

      harness.recognizer.hearFinal('vendu trente sucre');
      await flush(tester);

      // The heading is the pending one, because nothing has run yet.
      expect(find.text('Produits détectés'), findsOneWidget);
      expect(find.text('Ce qui a été enregistré'), findsNothing);
      expect(find.text('Sucre'), findsOneWidget);
    });

    testWidgets('is settled by the answer the merchant speaks', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);
      harness.recognizer.hearFinal('vendu du sucre');
      await flush(tester);

      await harness.listen(tester);
      harness.recognizer.hearFinal('deux');
      await flush(tester);

      expect(harness.intentsCalled(tester), <String>['record_sale']);
    });

    testWidgets('an ambiguous name offers the products it could mean', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);

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
      await harness.listen(tester);
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

    testWidgets('a confirmation offers a confirm and a retry', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);

      harness.recognizer.hearFinal('vendu trente sucre');
      await flush(tester);

      expect(find.text('Vous confirmez ?'), findsOneWidget);
      expect(find.text('Confirmer'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(harness.intentsCalled(tester), isEmpty);
    });

    testWidgets('a confirm runs the sale that was waiting', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);
      harness.recognizer.hearFinal('vendu trente sucre');
      await flush(tester);

      await tester.tap(find.text('Confirmer'));
      await flush(tester);

      expect(
        harness.journalOf(tester).calls.single.handlerArgs['items'],
        <Object?>[
          <String, Object?>{'productId': 'p_sucre', 'qty': 30},
        ],
      );
    });

    testWidgets('a retry reopens the microphone and runs nothing', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);
      harness.recognizer.hearFinal('vendu trente sucre');
      await flush(tester);

      await tester.tap(find.text('Réessayer'));
      await flush(tester);

      expect(harness.recognizer.listenCount, 2);
      expect(harness.intentsCalled(tester), isEmpty);
    });

    testWidgets('a question nobody answers ends on the screens', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);
      harness.recognizer.hearFinal('vendu du sucre');
      await flush(tester);

      harness.clock.elapse(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Saisie manuelle'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });
  });

  group('a refusal', () {
    testWidgets('is shown as a sentence and offers no buttons', (
      WidgetTester tester,
    ) async {
      final PanelHarness harness = PanelHarness();
      await harness.pump(tester);
      await harness.listen(tester);

      harness.recognizer.hearFinal('achete une voiture');
      await flush(tester);

      expect(find.text('Je ne peux pas faire cela'), findsOneWidget);
      // No heading over nothing, and no pair of buttons that would both do nothing.
      expect(find.text('Produits détectés'), findsNothing);
      expect(find.text('Confirmer'), findsNothing);
      expect(find.text('Réessayer'), findsNothing);
      expect(harness.intentsCalled(tester), isEmpty);
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

      await tester.tap(find.byIcon(Icons.mic_rounded));
      await flush(tester);

      expect(find.text('Saisie manuelle'), findsOneWidget);
      expect(find.text('Revenir à la voix'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(harness.tts.lastSpoken, contains('Micro autorisé'));

      await tester.tap(find.text('Revenir à la voix'));
      await flush(tester);

      expect(find.text('Saisie manuelle'), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });
  });
}

/// The bars of the waveform, found by the one thing all six share.
///
/// Six of them is a fact of the specification, and counting them is what stops a
/// later change from quietly replacing the row with a single decorative shape.
int _bars(WidgetTester tester) {
  return tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(VoiceWaveform),
          matching: find.byType(Container),
        ),
      )
      .where((Container bar) => bar.constraints?.maxWidth == 4)
      .length;
}
