import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// The two buttons that close a turn.
///
/// Equal width and one of each kind, because neither is more important than the
/// other: "Réessayer" and "Confirmer" are both legitimate answers to a question the
/// module asked, and a wider primary button would tell the merchant which one to
/// press before he has read the question. The primary is orange, the secondary is
/// white with a beige border, which is the specification's contrast and keeps the
/// filled button the only saturated thing on a cream panel.
///
/// The press scale is 0.98 over 180ms: enough to feel under a fingertip, short
/// enough that the button is already back before the merchant looks up from the
/// customer.
class VoiceActionRow extends StatelessWidget {
  const VoiceActionRow({
    super.key,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
  });

  final String secondaryLabel;

  final VoidCallback onSecondary;

  final String primaryLabel;

  final VoidCallback onPrimary;

  /// Whether the primary action can be taken.
  ///
  /// A disabled primary stays visible rather than disappearing: a button that comes
  /// and leaves the row moves everything the merchant was aiming at.
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.voicePanelLabel,
      child: Row(
        children: <Widget>[
          Expanded(
            child: VoiceActionButton(
              label: secondaryLabel,
              onPressed: onSecondary,
              filled: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: VoiceActionButton(
              label: primaryLabel,
              onPressed: primaryEnabled ? onPrimary : null,
              filled: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two actions, pressable and disabled.
///
/// Split out so both buttons are the same widget: two buttons written twice is how a
/// pair ends up one filled, one outlined, 4 pixels apart in height.
class VoiceActionButton extends StatefulWidget {
  const VoiceActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.filled,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final bool filled;

  static const double height = 56;

  @override
  State<VoiceActionButton> createState() => _VoiceActionButtonState();
}

class _VoiceActionButtonState extends State<VoiceActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool enabled = widget.onPressed != null;
    final Color background = widget.filled
        ? (enabled
              ? AppColors.secondary
              : AppColors.secondary.withValues(alpha: 0.4))
        : scheme.surfaceBright;
    final Color foreground = widget.filled
        ? (enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.6))
        : (enabled ? scheme.primary : scheme.onSurfaceVariant);

    final Widget label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    );

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(28),
          border: widget.filled
              ? null
              : Border.all(color: scheme.outlineVariant, width: 2),
          boxShadow: widget.filled && enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: enabled
                ? (bool pressed) => setState(() => _pressed = pressed)
                : null,
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: VoiceActionButton.height,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
