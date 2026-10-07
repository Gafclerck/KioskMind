import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';

/// The offer to finish the command on the screens instead of by voice.
///
/// It is a message and not a navigation: the manual screens are another feature's
/// to deliver, and voice must not hold a merchant hostage to a route that does not
/// exist yet. What it does offer is the way back, because a voice that has stopped
/// must never be a voice that cannot restart.
class VoiceManualEntryNotice extends StatelessWidget {
  const VoiceManualEntryNotice({super.key, required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.voiceManualTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(l10n.voiceManualMessage),
          TextButton(onPressed: onResume, child: Text(l10n.voiceBackToVoice)),
        ],
      ),
    );
  }
}
