import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/entities/product_snapshot.dart';

/// The products an ambiguous name could have meant.
///
/// Shown as a list and not as a question, because the merchant already said the
/// name and the session already found everything it can: what is left is for him
/// to point at the right line. The names are the catalog's, never a guess of the
/// session's, so what he picks is a real product id.
class VoiceCandidateChoices extends StatelessWidget {
  const VoiceCandidateChoices({
    super.key,
    required this.candidates,
    required this.onChosen,
  });

  final List<ProductSnapshot> candidates;

  /// Called with the product the merchant pointed at.
  final void Function(ProductSnapshot product) onChosen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.voiceChooseProduct),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final ProductSnapshot product in candidates)
              OutlinedButton(
                onPressed: () => onChosen(product),
                child: Text(product.name),
              ),
          ],
        ),
      ],
    );
  }
}
