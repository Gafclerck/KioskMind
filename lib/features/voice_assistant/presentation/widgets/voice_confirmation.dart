import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';

/// The yes and no of a confirmation.
///
/// Two buttons and not a spoken answer only: a confirmation is the one question
/// where a wrong tap costs a sale, and a merchant at a counter can read two words
/// faster than he can say them. Both are there, because a voice that can only be
/// answered out loud is a voice that needs a quiet shop.
class VoiceConfirmation extends StatelessWidget {
  const VoiceConfirmation({super.key, required this.onAnswer});

  /// Called with the merchant's answer, true for yes.
  final void Function(bool accepted) onAnswer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(onPressed: () => onAnswer(false), child: Text(l10n.voiceNo)),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => onAnswer(true),
          child: Text(l10n.voiceYes),
        ),
      ],
    );
  }
}
