import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/services/spoken_amount_formatter.dart';
import '../state/voice_message.dart';
import '../state/voice_outcome.dart';
import '../state/voice_recap.dart';
import '../state/voice_session_controller.dart';
import '../state/voice_session_state.dart';
import 'voice_action_row.dart';
import 'voice_audio_visualizer.dart';
import 'voice_candidate_choices.dart';
import 'voice_header.dart';
import 'voice_manual_entry_notice.dart';
import 'voice_message_text.dart';
import 'voice_results_panel.dart';
import 'voice_transcript.dart';
import 'voice_undo_banner.dart';

/// Everything the voice module shows, in the order it happens.
///
/// One widget to mount rather than eight to compose: a screen that hosts voice must
/// not have to know that a question has candidates and a confirmation has buttons,
/// and the order of the two zones is a decision of the module rather than of whoever
/// mounts it.
///
/// The two zones are the specification's. The green one is what the microphone is
/// doing; the cream one is what the module understood. A message that carries no
/// lines has no cards to draw, and then the panel shows the sentence instead of a
/// heading over nothing.
class VoicePanel extends ConsumerWidget {
  const VoicePanel({super.key, required this.onClose});

  /// Closes the sheet.
  ///
  /// Required and not optional: this panel is only ever shown as a sheet, and one
  /// that could not be dismissed would leave a merchant who does not want to talk
  /// stuck in front of a microphone.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoiceSessionState state = ref.watch(voiceSessionProvider);
    final VoiceSessionController controller = ref.read(
      voiceSessionProvider.notifier,
    );
    if (state.awaitingManualEntry) {
      return VoiceSpeaker(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            VoiceHeader(onClose: onClose),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: VoiceManualEntryNotice(onResume: controller.resume),
              ),
            ),
          ],
        ),
      );
    }
    return VoiceSpeaker(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          VoiceHeader(onClose: onClose),
          Flexible(child: _panel(context, state, controller)),
          _greenArea(context, state, controller),
        ],
      ),
    );
  }

  /// The green area: the microphone, what it heard, and the time left to undo.
  Widget _greenArea(
    BuildContext context,
    VoiceSessionState state,
    VoiceSessionController controller,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(color: AppColors.primary),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (state.canUndo)
            VoiceUndoBanner(
              state: state,
              onUndo: () => unawaited(controller.undo()),
            ),
          const SizedBox(height: 24),
          VoiceAudioVisualizer(
            state: state,
            onPressed: state.canListen
                ? () => unawaited(
                    state.status == VoiceSessionStatus.listening
                        ? controller.stopListening()
                        : controller.startListening(),
                  )
                : null,
          ),
          const SizedBox(height: 32),
          VoiceTranscript(state: state),
        ],
      ),
    );
  }

  /// The cream panel: the lines the module read, and the ways to answer.
  Widget _panel(
    BuildContext context,
    VoiceSessionState state,
    VoiceSessionController controller,
  ) {
    final VoiceMessage? message = state.message;
    if (message == null) {
      return VoiceResultsPanel(
        lines: const <VoiceRecapLine>[],
        isRecorded: false,
        summary: AppLocalizations.of(context).voiceIdleHint,
      );
    }
    final _PanelContent content = _PanelContent.of(message);

    return VoiceResultsPanel(
      lines: content.lines,
      total: content.total,
      isRecorded: content.isRecorded,
      summary: content.summary(context, message),
      child: _answers(context, state, message, controller),
    );
  }

  /// How the merchant answers what he is being asked.
  ///
  /// Three shapes, and they are not interchangeable. A question about which product
  /// was meant is settled by pointing at it, so it shows the products. A question
  /// about anything else is settled by agreeing or by saying it again, so it shows
  /// two buttons. A finished command is not a question at all: it shows the same two
  /// buttons, both of which reopen the microphone, because there is nothing left to
  /// decide.
  ///
  /// The button says "Confirmer" and not "Oui" because the merchant is agreeing to a
  /// command, and agreeing to a command is not the same gesture as answering yes to
  /// a question about one. It also says "Réessayer" and not "Non" because a no would
  /// raise a doubt without moving the merchant forward, while saying it again both
  /// declines and retries.
  Widget _answers(
    BuildContext context,
    VoiceSessionState state,
    VoiceMessage? message,
    VoiceSessionController controller,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (message is QuestionMessage) {
      final QuestionMessage question = message;
      if (question.candidates.isNotEmpty) {
        return VoiceCandidateChoices(
          candidates: question.candidates,
          onChosen: (product) => unawaited(
            controller.answer(asked: question.doubt, value: product),
          ),
        );
      }
      return _actions(
        l10n,
        enabled: !state.isBusy,
        secondary: l10n.voiceRetry,
        onSecondary: () => unawaited(controller.startListening()),
        primary: l10n.voiceConfirm,
        onPrimary: () =>
            unawaited(controller.confirm(question.doubt, accepted: true)),
      );
    }

    if (message is DoneMessage) {
      return _actions(
        l10n,
        enabled: state.canListen,
        secondary: l10n.voiceRetry,
        onSecondary: () => unawaited(controller.startListening()),
        primary: l10n.voiceNewCommand,
        onPrimary: () => unawaited(controller.startListening()),
      );
    }

    // A refusal, an undo failure, a fault: nothing to agree to and nothing to retry
    // but the microphone itself, so there are no buttons and the sentence has
    // already been drawn above. An empty answer keeps the panel's rhythm rather than
    // showing a pair of buttons that would both do nothing.
    return const SizedBox.shrink();
  }

  Widget _actions(
    AppLocalizations l10n, {
    required bool enabled,
    required String secondary,
    required VoidCallback onSecondary,
    required String primary,
    required VoidCallback onPrimary,
  }) {
    return VoiceActionRow(
      secondaryLabel: secondary,
      onSecondary: onSecondary,
      primaryLabel: primary,
      onPrimary: onPrimary,
      primaryEnabled: enabled,
    );
  }
}

/// What the panel draws, decided from the message in one place.
///
/// The rule "which message has lines, and does it have a total" belongs here rather
/// than in the panel, so no widget has to learn the shape of an outcome. A message
/// with no lines is not drawn as an empty list: the panel then shows the sentence
/// alone, and the merchant reads a refusal rather than a heading over nothing.
final class _PanelContent {
  const _PanelContent({
    this.lines = const <VoiceRecapLine>[],
    this.total,
    this.isRecorded = false,
    this.recap,
  });

  factory _PanelContent.of(VoiceMessage message) {
    return switch (message) {
      QuestionMessage(recap: final VoiceRecap? recap) =>
        recap == null
            ? const _PanelContent()
            : _PanelContent(lines: recap.lines, recap: recap),
      DoneMessage(outcome: final VoiceOutcome outcome) => _ofOutcome(outcome),
      UndoneMessage(outcome: final VoiceOutcome outcome) => _ofOutcome(outcome),
      _ => const _PanelContent(),
    };
  }

  /// A recorded sale is the one outcome that has both lines and a figure to total.
  ///
  /// A restock has lines and no figure, because the shop bought stock rather than
  /// sold it: showing a "total" there would print a cost as though it were revenue.
  /// An outcome that reports figures instead of lines has neither, and falls through
  /// to the sentence, which is the only form that can carry a day's takings or a
  /// list of low stock.
  static _PanelContent _ofOutcome(VoiceOutcome outcome) {
    return switch (outcome) {
      final SaleRecorded sale => _PanelContent(
        lines: sale.lines,
        total: sale.total,
        isRecorded: true,
      ),
      final RestockRecorded restock => _PanelContent(
        lines: restock.lines,
        isRecorded: true,
      ),
      final SaleCancelled cancelled => _PanelContent(
        lines: cancelled.lines,
        isRecorded: true,
      ),
      _ => const _PanelContent(),
    };
  }

  final List<VoiceRecapLine> lines;

  final double? total;

  /// Whether the command behind these lines has already run.
  final bool isRecorded;

  /// The command a question is about, when it has one.
  final VoiceRecap? recap;

  /// What the merchant has to read above the cards, or null when he has nothing.
  ///
  /// The rule is "does the sentence say something the cards do not", and only one
  /// case fails that test. A question does not repeat itself: "Combien ?" over two
  /// product cards and two buttons tells the merchant nothing about what he is being
  /// asked, and a recap's announced amounts are the reason the question is being
  /// asked at all.
  ///
  /// A finished command that has cards does repeat itself. Its cards carry its
  /// products, its unit prices and its total, which is strictly more than its
  /// sentence carried, and that sentence is what the module is speaking at this very
  /// moment, so printing it too would put the same line of text on the panel and in
  /// the merchant's ears twice.
  ///
  /// Everything else says its sentence, and the two cases that matter are a command
  /// with nothing to draw it as, and a cancellation: the cards of a cancelled sale
  /// list the products that went back on the shelf, which is not the same claim as
  /// "this sale no longer exists".
  String? summary(BuildContext context, VoiceMessage message) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (message is QuestionMessage) {
      final String asked = voiceMessageText(l10n, message);
      final String announced = recap == null
          ? ''
          : voiceRecapDetailsText(l10n, recap!, const SpokenAmountFormatter());
      return announced.isEmpty ? asked : '$asked - $announced';
    }
    if (message is DoneMessage && lines.isNotEmpty) {
      return null;
    }
    return voiceMessageText(l10n, message);
  }
}

/// Reads the session's sentence aloud, once per sentence.
///
/// The speaker is a widget and not a service because the sentence is a localised
/// string: only a widget that sits under the app's localisations can produce one.
/// It listens to the counter that changes with every sentence rather than to the
/// state itself, because the undo countdown changes the state several times a
/// second and a module that reads a new sentence on every tick talks over itself.
class VoiceSpeaker extends ConsumerStatefulWidget {
  const VoiceSpeaker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VoiceSpeaker> createState() => _VoiceSpeakerState();
}

class _VoiceSpeakerState extends ConsumerState<VoiceSpeaker> {
  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      voiceSessionProvider.select((VoiceSessionState state) => state.speechId),
      (int? previous, int next) {
        if (previous == next || !mounted) {
          return;
        }
        final VoiceMessage? message = ref.read(voiceSessionProvider).message;
        if (message == null) {
          return;
        }
        unawaited(
          ref
              .read(voiceSessionProvider.notifier)
              .speak(voiceMessageText(AppLocalizations.of(context), message)),
        );
      },
    );
    return widget.child;
  }
}
