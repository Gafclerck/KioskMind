import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../state/voice_session_state.dart';

/// The banner that offers to take back what was just written.
///
/// It shows the time left, because "Annuler" that disappears after ten seconds is
/// not an offer a merchant can act on: he has to know whether there is still time
/// before he decides to put the customer on hold to press it.
class VoiceUndoBanner extends StatelessWidget {
  const VoiceUndoBanner({super.key, required this.state, required this.onUndo});

  final VoiceSessionState state;

  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            Text(
              l10n.voiceUndoSeconds(state.remainingUndo.inSeconds),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            TextButton(onPressed: onUndo, child: Text(l10n.voiceUndoAction)),
          ],
        ),
      ),
    );
  }
}
