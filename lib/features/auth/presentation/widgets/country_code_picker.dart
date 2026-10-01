import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/country_codes.dart';
import '../providers/signup_provider.dart';
import 'country_code_picker_sheet.dart';

class CountryCodePicker extends ConsumerWidget {
  const CountryCodePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String code = ref.watch(
      signupProvider.select((SignupState state) => state.countryCode),
    );
    final CountryCode selected =
        countryCodeByDialCode(code) ?? countryCodes.first;

    return InkWell(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (BuildContext context) => const CountryCodePickerSheet(),
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
