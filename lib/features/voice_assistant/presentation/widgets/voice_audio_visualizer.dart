import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/voice_session_state.dart';
import 'voice_waveform.dart';

/// The microphone, its halo and the level it is reading.
///
/// Three layers and not one: the disc says what to press, the halo says the button
/// is alive, and the bars say it is hearing. They are separate because they answer
/// three different questions, and a single animated shape would answer none of them
/// on its own.
///
/// The orange is [AppColors.secondary] and never `colorScheme.secondary`: this sits
/// on the module's own green background, which does not change with the app theme,
/// so a themed secondary would put a pale tint on a dark green in dark mode.
class VoiceAudioVisualizer extends StatelessWidget {
  const VoiceAudioVisualizer({super.key, required this.state, this.onPressed});

  final VoiceSessionState state;

  /// Opens or closes the microphone. Null renders the visualizer as a picture of
  /// the microphone rather than as a control.
  final VoidCallback? onPressed;

  /// The diameter of the disc the merchant presses.
  static const double discSize = 72;

  /// The diameter of the halo behind the disc.
  static const double haloSize = 96;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _halo(context),
        const SizedBox(height: 20),
        VoiceWaveform(status: state.status),
      ],
    );
  }

  Widget _halo(BuildContext context) {
    return SizedBox(
      width: haloSize,
      height: haloSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          // Offset down and right rather than centred: a halo exactly behind the
          // disc reads as a border, an offset one reads as a glow.
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              width: haloSize,
              height: haloSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.19),
              ),
            ),
          ),
          _disc(context),
        ],
      ),
    );
  }

  Widget _disc(BuildContext context) {
    final Widget face = Container(
      width: discSize,
      height: discSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.31),
            blurRadius: 8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _iconOf(state.status),
          size: 28,
          color: AppColors.textPrimaryLight,
        ),
      ),
    );

    if (onPressed == null || !state.canListen) {
      return face;
    }
    return Semantics(
      button: true,
      label: VoiceMicTooltip.labelOf(AppLocalizations.of(context), state),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: face,
        ),
      ),
    );
  }

  /// What the microphone is doing, in shape.
  ///
  /// The same mapping the old icon button used, so the statuses stay readable to
  /// anyone who learned them: a merchant who pressed and heard nothing needs to see
  /// that the module is preparing rather than ignoring him.
  static IconData _iconOf(VoiceSessionStatus status) {
    return switch (status) {
      VoiceSessionStatus.idle => Icons.mic_rounded,
      VoiceSessionStatus.preparing => Icons.mic_rounded,
      VoiceSessionStatus.listening => Icons.mic_rounded,
      VoiceSessionStatus.thinking => Icons.hourglass_top_rounded,
      VoiceSessionStatus.speaking => Icons.volume_up_rounded,
    };
  }
}

/// What the microphone is doing, in words.
///
/// Its own tiny class rather than a function on the button: the button is now a
/// layer of the visualizer and no longer owns a label, but the label is still read
/// by the status line under the transcript and by the control's semantics.
abstract final class VoiceMicTooltip {
  /// What the microphone is doing, in the merchant's language.
  static String labelOf(AppLocalizations l10n, VoiceSessionState state) {
    return switch (state.status) {
      VoiceSessionStatus.idle => l10n.voiceMicTooltip,
      VoiceSessionStatus.preparing => l10n.voiceMicPreparing,
      VoiceSessionStatus.listening => l10n.voiceMicListening,
      VoiceSessionStatus.thinking => l10n.voiceMicThinking,
      VoiceSessionStatus.speaking => l10n.voiceMicSpeaking,
    };
  }
}
