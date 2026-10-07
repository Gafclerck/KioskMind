import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/voice_session_state.dart';
import 'voice_audio_visualizer.dart';

/// What the module heard, and what it is doing about it.
///
/// The transcript is the largest text on the green area because it is the only
/// thing on that area that the merchant did not choose to read: it is what the
/// microphone made of his words. The status line under it is in orange because
/// "je vous écoute" and "je traite" are different situations and he has to be able
/// to tell them apart from across a counter.
///
/// White and orange on green, both fixed rather than themed, for the reason
/// [VoiceAudioVisualizer] gives.
class VoiceTranscript extends StatelessWidget {
  const VoiceTranscript({super.key, required this.state});

  final VoiceSessionState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String transcript = state.lastHeard.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (transcript.isNotEmpty)
            Text(
              transcript,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            VoiceMicTooltip.labelOf(l10n, state),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
