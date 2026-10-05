import 'package:flutter/material.dart';

import '../../../../core/formatting/money.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/voice_outcome.dart';
import 'voice_product_card.dart';

/// The cream panel under the green area: what the module understood, and what it
/// did with it.
///
/// Two things are true at once about this panel, and the panel has to show both.
/// A confirmation is waiting, so the merchant must see the command before he agrees
/// to it. And a sale may already have been written, in which case the same cards are
/// the record of what he is looking at. It is therefore built from the same
/// [VoiceRecapLine]s either way, and the heading is the only thing that changes.
///
/// The heading changes because the two states are not the same promise. "Produits
/// détectés" is what the module found and has not yet done. "Ce qui a été
/// enregistré" is a sale that exists and can be undone. Reading the second one as the
/// first would tell the merchant his basket is still open when it is not.
class VoiceResultsPanel extends StatelessWidget {
  const VoiceResultsPanel({
    super.key,
    required this.lines,
    required this.isRecorded,
    this.total,
    this.summary,
    this.child,
  });

  /// The lines to draw, in the order the merchant said them.
  final List<VoiceRecapLine> lines;

  /// True once the command has run, false while a confirmation is pending.
  final bool isRecorded;

  /// The total of the command, when it has one.
  ///
  /// Null for a command that moves no money: a stock read has no total, and printing
  /// a zero would be a figure the merchant never had.
  final double? total;

  /// The question being asked, or null when the panel has none.
  ///
  /// Above the cards and never inside one: the merchant is being asked something,
  /// and the cards are what he is being asked it about. A panel that showed the
  /// question below the products would read as though the products were the answer.
  final String? summary;

  /// What goes under the lines: the action row, or the answer choices.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // No heading without something under it: a panel reading "Produits
                // détectés" over a refusal is a heading for a list that is not there.
                if (lines.isNotEmpty || total != null) ...<Widget>[
                  _heading(context),
                  const SizedBox(height: 20),
                ],
                if (summary case final String said) ...<Widget>[
                  Text(said, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                ],
                for (final VoiceRecapLine line in lines) ...<Widget>[
                  VoiceProductCard(line: line),
                  const SizedBox(height: 12),
                ],
                if (total case final double amount) ...<Widget>[
                  const SizedBox(height: 8),
                  _total(context, scheme, amount),
                ],
                if (child case final Widget below) ...<Widget>[
                  const SizedBox(height: 20),
                  below,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Text(
      isRecorded ? l10n.voiceRecordedProducts : l10n.voiceDetectedProducts,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _total(BuildContext context, ColorScheme scheme, double amount) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.voiceTotalLabel,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: 15),
            ),
          ),
          Text(
            formatCfa(amount),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
