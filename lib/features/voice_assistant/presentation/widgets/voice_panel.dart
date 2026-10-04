import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../state/voice_message.dart';
import '../state/voice_session_controller.dart';
import '../state/voice_session_state.dart';
import 'voice_candidate_choices.dart';
import 'voice_confirmation.dart';
import 'voice_manual_entry_notice.dart';
import 'voice_message_text.dart';
import 'voice_mic_button.dart';
import 'voice_undo_banner.dart';

/// Everything the voice module shows, in the order it happens.
///
/// One widget to mount rather than six to compose: a screen that hosts voice must
/// not have to know that a question has candidates and a confirmation has buttons,
/// and the order of the three rows is a decision of the module rather than of
/// whoever mounts it.
class VoicePanel extends ConsumerWidget {
  const VoicePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoiceSessionState state = ref.watch(voiceSessionProvider);
    final VoiceSessionController controller = ref.read(
      voiceSessionProvider.notifier,
    );
    if (state.awaitingManualEntry) {
      return VoiceSpeaker(
        child: VoiceManualEntryNotice(onResume: controller.resume),
      );
    }
    return VoiceSpeaker(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _VoiceMessage(state: state, controller: controller),
          if (state.canUndo)
            VoiceUndoBanner(
              state: state,
              onUndo: () => unawaited(controller.undo()),
            ),
          Center(
            child: VoiceMicButton(
              state: state,
              onPressed: () => unawaited(
                state.status == VoiceSessionStatus.listening
                    ? controller.stopListening()
                    : controller.startListening(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sentence the session has to say, and the ways to answer it.
class _VoiceMessage extends StatelessWidget {
  const _VoiceMessage({required this.state, required this.controller});

  final VoiceSessionState state;

  final VoiceSessionController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final VoiceMessage? message = state.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (state.lastHeard.isNotEmpty)
          Text(
            '${l10n.voiceHeardLabel}: ${state.lastHeard}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        Text(
          message == null
              ? l10n.voiceIdleHint
              : voiceMessageText(l10n, message),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (message case final QuestionMessage question)
          if (question.candidates.isNotEmpty)
            VoiceCandidateChoices(
              candidates: question.candidates,
              onChosen: (product) => unawaited(
                controller.answer(asked: question.doubt, value: product),
              ),
            )
          else if (question.isYesOrNo)
            VoiceConfirmation(
              onAnswer: (bool accepted) => unawaited(
                controller.confirm(question.doubt, accepted: accepted),
              ),
            ),
      ],
    );
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
