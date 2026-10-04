import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/voice_services/speech_recognizer_port.dart';
import 'package:kiosk_mind/core/voice_services/speech_service_error.dart';
import 'package:kiosk_mind/features/voice_assistant/di/voice_dependencies.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/clarification_slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_message.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_session_controller.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_session_state.dart';

import 'fake_clock.dart';
import 'fake_speech_services.dart';

/// The session of a container whose microphone and voice are fakes.
///
/// The whole composition root is kept and only the two device services are
/// replaced: a session built here runs the same parser, the same policy and the
/// same handlers as the app, so a test that says "a spoken sale opens the undo
/// window" says it about the pipeline and not about a hand-built variant.
class SessionHarness {
  SessionHarness({SpeechReadiness readiness = SpeechReadiness.ready}) {
    recognizer = FakeSpeechRecognizer(readiness: readiness);
    tts = FakeTts();
    clock = FakeClock(DateTime(2026, 3, 14, 9, 30));
    container = ProviderContainer(
      overrides: <Override>[
        voiceRecognizerProvider.overrideWith((Ref ref) async => recognizer),
        voiceTtsProvider.overrideWithValue(tts),
        voiceClockProvider.overrideWithValue(clock),
      ],
    );
  }

  late final ProviderContainer container;
  late final FakeSpeechRecognizer recognizer;
  late final FakeTts tts;
  late final FakeClock clock;

  VoiceSessionState get state => container.read(voiceSessionProvider);

  VoiceSessionController get controller =>
      container.read(voiceSessionProvider.notifier);

  HandlerCallJournal get journal => container.read(voiceCallJournalProvider);

  /// The ids of the use cases that ran, in order.
  List<String> get intentsCalled =>
      journal.calls.map((HandlerCall call) => call.intentId).toList();

  /// Moves time forward and lets the session's own ticker notice it.
  Future<void> elapse(Duration by) async {
    clock.elapse(by);
    await Future<void>.delayed(kSessionTickInterval * 2);
  }

  void dispose() => container.dispose();
}

void main() {
  // The composition root reads the bundled assets, which needs the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the microphone', () {
    test('is opened only when the merchant pressed it', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);

      expect(harness.recognizer.initializeCount, 0);

      await harness.controller.startListening();

      expect(harness.recognizer.initializeCount, 1);
      expect(harness.recognizer.listenCount, 1);
      expect(harness.state.status, VoiceSessionStatus.listening);
    });

    test('is silenced before it opens', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.speak('bonjour');

      await harness.controller.startListening();

      expect(harness.tts.stopCount, greaterThan(0));
    });

    test('shows what is heard while the merchant is still talking', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.startListening();

      harness.recognizer.hear('vendu deux');

      expect(harness.state.lastHeard, 'vendu deux');
      expect(harness.state.status, VoiceSessionStatus.listening);
    });

    test('is closed once a sentence is finished', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.startListening();

      harness.recognizer.hearFinal('vendu deux savon');
      await Future<void>.delayed(Duration.zero);

      expect(harness.recognizer.stopCount, 1);
      expect(harness.recognizer.cancelCount, 1);
      expect(harness.intentsCalled, <String>['record_sale']);
      expect(harness.state.lastHeard, isEmpty);
    });

    test('resets lastHeard and cancels recognizer on stopListening', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.startListening();
      harness.recognizer.hear('vendu');
      expect(harness.state.lastHeard, 'vendu');

      await harness.controller.stopListening();

      expect(harness.state.status, VoiceSessionStatus.idle);
      expect(harness.state.lastHeard, isEmpty);
      expect(harness.recognizer.cancelCount, greaterThan(0));
    });

    test(
      'discards trailing utterances received after listening stopped',
      () async {
        final SessionHarness harness = SessionHarness();
        addTearDown(harness.dispose);
        await harness.controller.startListening();
        harness.recognizer.hearFinal('vendu deux savon');
        await Future<void>.delayed(Duration.zero);
        expect(harness.state.status, VoiceSessionStatus.idle);
        expect(harness.state.lastHeard, isEmpty);

        // Trailing event from engine after turn completed
        harness.recognizer.hear('unwanted late utterance');
        expect(harness.state.lastHeard, isEmpty);
      },
    );

    test('resets lastHeard when starting a new listening session', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.startListening();
      harness.recognizer.hear('vendu deux');
      expect(harness.state.lastHeard, 'vendu deux');

      // Now stop and start listening again: must reset lastHeard to empty
      await harness.controller.stopListening();
      await harness.controller.startListening();

      expect(harness.state.lastHeard, isEmpty);
      expect(harness.state.status, VoiceSessionStatus.listening);
    });

    test('resets lastHeard when microphone fails', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.startListening();
      harness.recognizer.hear('vendu');
      expect(harness.state.lastHeard, 'vendu');

      harness.recognizer.fail(
        const SpeechServiceError(SpeechFault.listenFailed),
      );

      expect(harness.state.lastHeard, isEmpty);
      expect(harness.state.status, VoiceSessionStatus.idle);
    });

    test('a refused permission ends the attempt on the screens', () async {
      final SessionHarness harness = SessionHarness(
        readiness: SpeechReadiness.permissionDenied,
      );
      addTearDown(harness.dispose);

      await harness.controller.startListening();

      expect(harness.recognizer.listenCount, 0);
      expect(harness.state.canListen, isFalse);
      expect(harness.state.awaitingManualEntry, isTrue);
      expect(
        (harness.state.message! as MicUnavailableMessage).fault,
        SpeechFault.permissionDenied,
      );
    });

    test('a device without a recogniser says so', () async {
      final SessionHarness harness = SessionHarness(
        readiness: SpeechReadiness.unsupported,
      );
      addTearDown(harness.dispose);

      await harness.controller.startListening();

      expect(
        (harness.state.message! as MicUnavailableMessage).fault,
        SpeechFault.unsupported,
      );
    });

    test('an engine failure during the session ends it too', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.startListening();

      harness.recognizer.fail(
        const SpeechServiceError(SpeechFault.permissionDenied),
      );

      expect(harness.state.awaitingManualEntry, isTrue);
      expect(harness.state.canListen, isFalse);
    });

    test('comes back when the merchant asks for the voice again', () async {
      final SessionHarness harness = SessionHarness(
        readiness: SpeechReadiness.permissionDenied,
      );
      addTearDown(harness.dispose);
      await harness.controller.startListening();

      harness.controller.resume();

      expect(harness.state.awaitingManualEntry, isFalse);
      expect(harness.state.message, isNull);
      expect(harness.state.canListen, isTrue);
    });
  });

  group('a command that runs', () {
    test('records the sale and opens the undo window', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);

      await harness.controller.submit('vendu deux savon');

      expect(harness.journal.calls.single.handlerArgs['items'], <Object?>[
        <String, Object?>{'productId': 'p_savon', 'qty': 2},
      ]);
      expect(
        (harness.state.message! as DoneMessage).outcome,
        isA<SaleRecorded>().having(
          (SaleRecorded sale) => sale.lines,
          'lines',
          <VoiceRecapLine>[(name: 'Savon de ménage', qty: 2.0, unit: 'PIECE')],
        ),
      );
      expect(harness.state.canUndo, isTrue);
      expect(harness.state.undoSaleId, isNotNull);
      expect(harness.state.remainingUndo, greaterThan(Duration.zero));
    });

    test('keeps the microphone closed while it talks', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      final Completer<void> talking = Completer<void>();
      harness.tts.gate = talking;

      final Future<void> saying = harness.controller.speak('deux savons');

      expect(harness.state.status, VoiceSessionStatus.speaking);
      expect(harness.state.canListen, isFalse);
      talking.complete();
      await saying;

      expect(harness.tts.spoken, <String>['deux savons']);
      expect(harness.state.status, VoiceSessionStatus.idle);
    });
  });

  group('a question', () {
    test('asks for the quantity and runs once it is given', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);

      await harness.controller.submit('vendu du sucre');
      final QuestionMessage question =
          harness.state.message! as QuestionMessage;

      expect(question.slot, ClarificationSlot.itemQty);
      expect(question.doubt, DoubtKind.missingQuantity);
      expect(harness.state.canUndo, isFalse);

      await harness.controller.submit('deux');

      expect(harness.intentsCalled, <String>['record_sale']);
      expect(harness.state.message, isA<DoneMessage>());
    });

    test('offers the products an ambiguous name could mean', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);

      await harness.controller.submit('vendu deux huiles');
      final QuestionMessage question =
          harness.state.message! as QuestionMessage;

      expect(question.doubt, DoubtKind.ambiguousProduct);
      expect(
        question.candidates.map((ProductSnapshot product) => product.id),
        <String>['p_huile', 'p_huile_palme'],
      );
    });

    test('settles by pointing at one of them', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.submit('vendu deux huiles');
      final QuestionMessage question =
          harness.state.message! as QuestionMessage;

      await harness.controller.answer(
        asked: question.doubt,
        value: question.candidates.first,
      );

      expect(harness.journal.calls.single.handlerArgs['items'], <Object?>[
        <String, Object?>{'productId': 'p_huile', 'qty': 2},
      ]);
    });

    test(
      'a confirmation waits for a yes and runs nothing on its own',
      () async {
        final SessionHarness harness = SessionHarness();
        addTearDown(harness.dispose);

        await harness.controller.submit('vendu trente sucre');
        final QuestionMessage question =
            harness.state.message! as QuestionMessage;

        expect(question.slot, ClarificationSlot.confirmed);
        expect(question.isYesOrNo, isTrue);
        expect(harness.journal.calls, isEmpty);
      },
    );

    test('a yes settles the confirmation and the sale runs', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.submit('vendu trente sucre');
      final QuestionMessage question =
          harness.state.message! as QuestionMessage;

      await harness.controller.confirm(question.doubt, accepted: true);

      expect(harness.journal.calls.single.handlerArgs['items'], <Object?>[
        <String, Object?>{'productId': 'p_sucre', 'qty': 30},
      ]);
    });

    test('a no settles nothing and asks again', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.submit('vendu trente sucre');
      final QuestionMessage question =
          harness.state.message! as QuestionMessage;

      await harness.controller.confirm(question.doubt, accepted: false);

      expect(harness.state.message, isA<QuestionMessage>());
      expect(harness.journal.calls, isEmpty);
    });
  });

  group('a refusal', () {
    test('is stated and runs nothing', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);

      await harness.controller.submit('supprime le sucre');

      expect(harness.state.message, isA<RefusalMessage>());
      expect(harness.journal.calls, isEmpty);
    });
  });

  group('undo', () {
    test('takes the sale of the window back', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.submit('vendu deux savon');

      await harness.controller.undo();

      expect(harness.state.message, isA<UndoneMessage>());
      expect(harness.state.canUndo, isFalse);
      expect(harness.intentsCalled, <String>[
        'record_sale',
        'cancel_last_sale',
      ]);
    });

    test('does nothing when there is no window to open', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);

      await harness.controller.undo();

      expect(harness.state.message, isNull);
      expect(harness.intentsCalled, isEmpty);
    });

    test('says so when the press arrives after the deadline', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.submit('vendu deux savon');

      // The countdown is only read by the session's own tick, so a press can
      // arrive on a banner the merchant still sees while the window is already
      // shut. That press asks the use case, and the use case answers.
      harness.clock.elapse(const Duration(seconds: 11));
      await Future<void>.delayed(Duration.zero);
      expect(harness.state.canUndo, isTrue);

      await harness.controller.undo();

      expect(harness.state.message, isA<NothingToUndoMessage>());
    });

    test('does nothing once the window is closed', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.submit('vendu deux savon');

      await harness.elapse(const Duration(seconds: 11));
      await harness.controller.undo();

      expect(harness.state.canUndo, isFalse);
      expect(harness.intentsCalled, isNot(contains('cancel_last_sale')));
    });

    test('the banner closes with the window', () async {
      final SessionHarness harness = SessionHarness();
      addTearDown(harness.dispose);
      await harness.controller.submit('vendu deux savon');
      expect(harness.state.canUndo, isTrue);

      await harness.elapse(const Duration(seconds: 11));

      expect(harness.state.canUndo, isFalse);
      expect(harness.state.undoSaleId, isNull);
    });
  });
}
