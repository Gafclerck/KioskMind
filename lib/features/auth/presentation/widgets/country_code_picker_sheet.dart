import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/country_codes.dart';
import '../providers/signup_provider.dart';

class CountryCodePickerSheet extends ConsumerStatefulWidget {
  const CountryCodePickerSheet({super.key});

  @override
  ConsumerState<CountryCodePickerSheet> createState() =>
      _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState
    extends ConsumerState<CountryCodePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CountryCode> get _filteredCountries {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return countryCodes;
    }
    return countryCodes
        .where(
          (CountryCode country) =>
              country.label.toLowerCase().contains(query) ||
              country.code.toLowerCase().contains(query),
        )
        .toList();
  }

  void _select(CountryCode country) {
    ref.read(signupProvider.notifier).selectCountryCode(country.code);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final String currentCode = ref.watch(
      signupProvider.select((SignupState state) => state.countryCode),
    );
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Choisir un pays',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                key: const ValueKey<String>('country_search'),
                controller: _searchController,
                onChanged: (String value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher un pays',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredCountries.length,
                itemBuilder: (BuildContext context, int index) {
                  final CountryCode country = _filteredCountries[index];
                  final bool isSelected = country.code == currentCode;
                  return ListTile(
                    title: Text(country.label),
                    subtitle: Text(country.code),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => _select(country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
