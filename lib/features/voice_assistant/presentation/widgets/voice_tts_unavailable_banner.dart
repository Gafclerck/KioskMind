import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/voice_services/tts_port.dart';
import '../state/voice_session_state.dart';

/// The small notice that explains a recap that is heard on the screen only.
///
/// It is information and nothing else: no button, no offer to leave the sheets,
/// because nothing is broken that a tap would fix. The microphone stays usable,
/// the sentence stays on screen, and this banner just says why there is no voice
/// - which is the only thing a merchant who heard nothing can be told. It
/// distinguishes a phone without the voice from an engine that has not answered
/// yet, because one of the two may fix itself within the session.
class VoiceTtsUnavailableBanner extends StatelessWidget {
  const VoiceTtsUnavailableBanner({super.key, required this.state});

  final VoiceSessionState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String message = switch (state.ttsAvailability) {
      TtsAvailability.localeUnavailable => l10n.voiceTtsUnavailable,
      TtsAvailability.engineUnreachable => l10n.voiceTtsEngineUnreachable,
      TtsAvailability.ready || TtsAvailability.unknown => throw StateError(
        'banner shown without an unavailable verdict',
      ),
    };
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.volume_off_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
