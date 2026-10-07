import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// The title of the session and the way out of it.
///
/// A title and a close button and not a drag handle alone: the handle is a gesture,
/// and a merchant holding a customer with one hand has one finger. The button is 36
/// pixels, which is the specification's size, so it is padded to the 48 pixels a
/// fingertip needs without looking any bigger than the design.
///
/// White on green at 13%: the sheet's own surface is the green, so this sits on
/// [AppColors.primary] and not on `colorScheme.primary`, which turns pale in dark
/// mode and would leave white text on light green.
class VoiceHeader extends StatelessWidget {
  const VoiceHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.voiceSheetTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.voiceClose,
            child: Material(
              color: Colors.white.withValues(alpha: 0.13),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onClose,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
