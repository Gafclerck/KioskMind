import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/country_codes.dart';
import '../providers/signup_provider.dart';
import 'country_code_picker_sheet.dart';

/// Sélecteur d'indicatif, réutilisé par l'inscription et l'édition du profil.
///
/// Sans [onChanged], il reste lié au [signupProvider] (usage historique).
/// Avec [code] + [onChanged], il est piloté par n'importe quel état local.
class CountryCodePicker extends ConsumerWidget {
  const CountryCodePicker({super.key, this.code, this.onChanged});

  final String? code;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentCode = onChanged == null
        ? ref.watch(
            signupProvider.select((SignupState state) => state.countryCode),
          )
        : code ?? '+225';
    final CountryCode selected =
        countryCodeByDialCode(currentCode) ?? countryCodes.first;

    return InkWell(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (BuildContext context) =>
              CountryCodePickerSheet(code: currentCode, onChanged: onChanged),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Indicatif',
          prefixIcon: Icon(Icons.flag_outlined),
          suffixIcon: Icon(Icons.expand_more),
        ),
        child: Text(
          selected.code,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}
