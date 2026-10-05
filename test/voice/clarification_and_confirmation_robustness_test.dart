import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/voice_services/speech_recognizer_port.dart';
import 'package:kiosk_mind/core/voice_services/speech_service_error.dart';
import 'package:kiosk_mind/features/voice_assistant/di/voice_dependencies.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/dialog/dialog_manager.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/clarification_slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/handle_utterance.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_message.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_session_controller.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_session_state.dart';

import 'fake_clock.dart';
import 'fake_speech_services.dart';

class _RobustnessSessionHarness {
  _RobustnessSessionHarness({
    SpeechReadiness readiness = SpeechReadiness.ready,
  }) {
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

  DialogManager get dialog => container.read(voiceDialogProvider);

  Future<void> elapse(Duration by) async {
    clock.elapse(by);
    await Future<void>.delayed(kSessionTickInterval * 2);
  }

  void dispose() {
    container.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Confirmation & Clarification Robustness', () {
    test('QuestionMessage.isYesOrNo is true whenever slot is confirmed', () {
      const QuestionMessage msgWithConfirmedSlot = QuestionMessage(
        doubt: DoubtKind.outOfDomain,
        slot: ClarificationSlot.confirmed,
      );
      expect(msgWithConfirmedSlot.isYesOrNo, isTrue);

      const QuestionMessage msgWithQuantitySlot = QuestionMessage(
        doubt: DoubtKind.missingQuantity,
        slot: ClarificationSlot.itemQty,
      );
      expect(msgWithQuantitySlot.isYesOrNo, isFalse);

      const QuestionMessage msgWithProductSlot = QuestionMessage(
        doubt: DoubtKind.missingProduct,
        slot: ClarificationSlot.itemProductName,
      );
      expect(msgWithProductSlot.isYesOrNo, isFalse);

      const QuestionMessage msgWithAmountMismatch = QuestionMessage(
        doubt: DoubtKind.amountMismatch,
        slot: ClarificationSlot.confirmed,
      );
      expect(msgWithAmountMismatch.isYesOrNo, isTrue);
    });

    test(
      'Saying "annule" during a clarification cancels cleanly without manual entry',
      () async {
        final _RobustnessSessionHarness harness = _RobustnessSessionHarness();
        addTearDown(harness.dispose);

        // Step 1: Start a command missing product or quantity
        await harness.controller.submit('vendu deux');
        expect(harness.state.message, isA<QuestionMessage>());
        expect(harness.dialog.pending, isNotNull);
        expect(harness.state.awaitingManualEntry, isFalse);

        // Step 2: Merchant changes mind and says "annule"
        await harness.controller.submit('annule');
        expect(harness.dialog.pending, isNull);
        expect(harness.state.awaitingManualEntry, isFalse);
        expect(harness.dialog.state, VoiceDialogState.idle);
      },
    );

    test(
      'Saying "stop" during a missing quantity clarification cancels cleanly',
      () async {
        final _RobustnessSessionHarness harness = _RobustnessSessionHarness();
        addTearDown(harness.dispose);

        await harness.controller.submit('vendu du sucre');
        expect(harness.state.message, isA<QuestionMessage>());
        expect(harness.dialog.pending, isNotNull);

        await harness.controller.submit('stop');
        expect(harness.dialog.pending, isNull);
        expect(harness.state.awaitingManualEntry, isFalse);
      },
    );

    test(
      'Non-terminal speech faults during a question do not drop to manual entry',
      () async {
        final _RobustnessSessionHarness session = _RobustnessSessionHarness();
        addTearDown(session.dispose);

        // Ask a clarification question
        await session.controller.submit('vendu du sucre');
        expect(session.state.message, isA<QuestionMessage>());
        expect(session.state.awaitingManualEntry, isFalse);

        // Simulate recognizer listening and hitting silence timeout (listenFailed)
        await session.controller.startListening();
        expect(session.state.status, VoiceSessionStatus.listening);

        session.recognizer.fail(
          const SpeechServiceError(SpeechFault.listenFailed),
        );

        // The question is STILL pending, status is idle, and NOT dropped to manual entry
        expect(session.state.status, VoiceSessionStatus.idle);
        expect(session.state.awaitingManualEntry, isFalse);
        expect(session.state.message, isA<QuestionMessage>());

        // Merchant can now answer with "deux" and successfully finish the command
        await session.controller.submit('deux');
        expect(session.state.awaitingManualEntry, isFalse);
        expect(session.journal.calls.single.intentId, equals('record_sale'));
      },
    );

    test(
      'startListening touches the dialog question deadline so merchant has full response window',
      () async {
        final _RobustnessSessionHarness session = _RobustnessSessionHarness();
        addTearDown(session.dispose);

        await session.controller.submit('vendu du sucre');
        expect(session.state.message, isA<QuestionMessage>());

        // 8 seconds pass while TTS was speaking
        await session.elapse(const Duration(seconds: 8));

        // Merchant presses mic to answer: startListening touches dialog deadline
        await session.controller.startListening();

        // 8 more seconds pass (total 16s, which would have expired the original 10s timeout)
        await session.elapse(const Duration(seconds: 8));

        // Session is STILL valid and NOT expired into manual entry
        expect(session.state.awaitingManualEntry, isFalse);
        expect(session.state.message, isA<QuestionMessage>());

        // Merchant speaks answer
        await session.controller.submit('cinq');
        expect(session.state.awaitingManualEntry, isFalse);
        expect(session.journal.calls.single.intentId, equals('record_sale'));
      },
    );

    test(
      'Saying "non" to a confirmation asks again without executing or dropping to manual entry',
      () async {
        final _RobustnessSessionHarness session = _RobustnessSessionHarness();
        addTearDown(session.dispose);

        await session.controller.submit('j ai vendu un riz a mille cinq cents');
        expect(session.state.message, isA<QuestionMessage>());
        expect(session.dialog.pending, isNotNull);
        expect(session.dialog.pending!.slot, equals(ClarificationSlot.confirmed));

        await session.controller.submit('non');
        expect(session.dialog.pending, isNotNull);
        expect(session.state.message, isA<QuestionMessage>());
        expect(session.state.awaitingManualEntry, isFalse);
        expect(session.journal.calls, isEmpty);
      },
    );

    test(
      'Switching intent during a pending clarification cancels old question and executes new intent',
      () async {
        final _RobustnessSessionHarness session = _RobustnessSessionHarness();
        addTearDown(session.dispose);

        await session.controller.submit('vendu du sucre');
        expect(session.state.message, isA<QuestionMessage>());
        expect(session.dialog.pending, isNotNull);

        await session.controller.submit('combien de riz en stock');
        expect(session.dialog.pending, isNull);
        expect(session.state.awaitingManualEntry, isFalse);
        expect(session.journal.calls.single.intentId, equals('query_stock'));
      },
    );
  });
}
