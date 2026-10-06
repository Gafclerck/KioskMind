import 'package:flutter/material.dart';

import '../../../../core/formatting/money.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../state/voice_outcome.dart';
import 'voice_message_text.dart';

/// One product of a recap, as a card.
///
/// The card is the only place the merchant sees a figure he did not say: the price
/// the handler applied to a quantity he announced. It is shown rather than left out
/// because a confirmation asking him to agree to a total without showing the
/// arithmetic is asking him to trust a number.
///
/// The initial letter is not a photo. A voice session names products the merchant
/// never saw on this screen, so there is no thumbnail to show, and an empty box or a
/// generic icon would read as a product that failed to load.
class VoiceProductCard extends StatelessWidget {
  const VoiceProductCard({super.key, required this.line});

  final VoiceRecapLine line;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceBright,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          _initial(context, scheme),
          const SizedBox(width: 12),
          // Expanded, so the name wraps and pushes the price along instead of
          // overflowing it on the narrow phones the specification calls out.
          Expanded(child: _nameAndDetail(context, scheme)),
          const SizedBox(width: 8),
          _price(context, scheme),
        ],
      ),
    );
  }

  Widget _initial(BuildContext context, ColorScheme scheme) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _initialOf(line.name),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _nameAndDetail(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          line.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          _detail(AppLocalizations.of(context)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// "5 bouteilles × 2,500 F" when the line has a price, and the counted product
  /// alone when it has none.
  ///
  /// A restock carries no selling price, so it shows "10 sacs" rather than a price
  /// the shop never charged. A named product with no count shows only its unit, for
  /// the same reason: a read moves nothing and has no quantity to print.
  ///
  /// The unit is written out rather than printed as the catalog's code, because "5
  /// PIECE" is not something a merchant reads; and the price carries the same "F"
  /// suffix as the total above it, so a line and a total are read the same way.
  String _detail(AppLocalizations l10n) {
    final String unit = voiceUnitLabel(l10n, line.qty, line.unit);
    final double? price = line.unitPrice;
    if (price == null) {
      return '${_quantity(line.qty)} $unit';
    }
    return '${_quantity(line.qty)} $unit × ${formatCfa(price, suffix: 'F')}';
  }

  Widget _price(BuildContext context, ColorScheme scheme) {
    final double? price = line.unitPrice;
    if (price == null) {
      return const SizedBox.shrink();
    }
    return Text(
      formatCfa(line.qty * price),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// The quantity as the merchant said it, with a comma and no trailing zero.
  ///
  /// A synthesiser mangles "2.5", but this is read with the eyes, where the French
  /// comma is correct, and a trailing ".0" is noise. Two decimals are enough because
  /// a shop weighs in kilos, not in grams.
  static String _quantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toStringAsFixed(0);
    }
    return qty
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceAll('.', ',');
  }

  /// The first letter of the name, uppercased, or a dot when there is no letter.
  static String _initialOf(String name) {
    for (final int rune in name.trim().runes) {
      final String character = String.fromCharCode(rune);
      if (RegExp(r'\p{L}', unicode: true).hasMatch(character)) {
        return character.toUpperCase();
      }
    }
    return '·';
  }
}
