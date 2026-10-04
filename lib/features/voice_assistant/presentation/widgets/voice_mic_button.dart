import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../state/voice_session_state.dart';

/// The microphone, and what it is doing.
///
/// One button for the whole lifecycle of a listening session, because a merchant
/// at a counter needs one thing to press and not three states to understand. It
/// says what it is doing in words as well as in shape: a button that stays
/// unresponsive while the module thinks looks exactly like one that is broken.
class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton({
    super.key,
    required this.state,
    required this.onPressed,
  });

  final VoiceSessionState state;

  /// Starts a session, or closes the one in progress.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String label = labelOf(l10n, state);
    return Semantics(
      button: true,
      label: l10n.voicePanelLabel,
      child: IconButton.filled(
        onPressed: state.canListen ? onPressed : null,
        icon: Icon(_iconOf(state)),
        tooltip: label,
      ),
    );
  }

  /// What the microphone is doing, in words.
  static String labelOf(AppLocalizations l10n, VoiceSessionState state) {
    return switch (state.status) {
      VoiceSessionStatus.idle => l10n.voiceMicTooltip,
      VoiceSessionStatus.preparing => l10n.voiceMicPreparing,
      VoiceSessionStatus.listening => l10n.voiceMicListening,
      VoiceSessionStatus.thinking => l10n.voiceMicThinking,
      VoiceSessionStatus.speaking => l10n.voiceMicSpeaking,
    };
  }

  /// What the microphone is doing, in shape.
  static IconData _iconOf(VoiceSessionState state) {
    return switch (state.status) {
      VoiceSessionStatus.idle => Icons.mic_none,
      VoiceSessionStatus.preparing => Icons.mic,
      VoiceSessionStatus.listening => Icons.mic,
      VoiceSessionStatus.thinking => Icons.hourglass_top,
      VoiceSessionStatus.speaking => Icons.volume_up,
    };
  }
}
