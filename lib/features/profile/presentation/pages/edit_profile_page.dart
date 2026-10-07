import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../auth/domain/auth_validators.dart';
import '../../../auth/presentation/widgets/country_code_picker.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/edit_profile_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/profile_avatar.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

/// Types d'activité proposés dans le menu déroulant.
const List<String> _presetBusinessTypes = <String>[
  'Épicerie / Alimentation',
  'Habillement / Textile',
  'Électronique / Téléphonie',
  'Restauration / Snack',
  'Cosmétique / Beauté',
  'Service',
  'Autre',
];

/// Valeur du menu qui libère une saisie libre à côté.
const String _customBusinessTypeOption = 'Autre';

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _kioskNameController = TextEditingController();
  final TextEditingController _marketLocationController =
      TextEditingController();
  final TextEditingController _customBusinessTypeController =
      TextEditingController();
  bool _hydrated = false;

  /// Sélection courante du menu d'activité ; `null` tant que le commerçant n'a
  /// pas choisi. Vaut « Autre » quand la saisie libre est affichée.
  String? _businessTypeSelection;

  /// Vrai quand le champ de saisie libre d'activité est visible.
  bool get _showsCustomBusinessType =>
      _businessTypeSelection == _customBusinessTypeOption;

  /// Traduit une valeur stockée en sélection de menu : une valeur absante ne
  /// présélectionne rien, une valeur qui n'est plus proposée retombe sur
  /// « Autre » pour que la saisie reste visible et modifiable.
  String? _selectionFor(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value == _customBusinessTypeOption) {
      return _customBusinessTypeOption;
    }
    return _presetBusinessTypes.contains(value)
        ? value
        : _customBusinessTypeOption;
  }

  void _onBusinessTypeSelected(String? selection) {
    if (selection == null) {
      return;
    }
    setState(() {
      _businessTypeSelection = selection;
    });
    if (selection != _customBusinessTypeOption) {
      _customBusinessTypeController.clear();
      ref.read(editProfileProvider.notifier).setBusinessType(selection);
      return;
    }
    // « Autre » : le champ libre devient la source de vérité. S'il porte déjà
    // du texte, on l'adopte tel quel pour ne pas perdre la saisie.
    _onCustomBusinessTypeChanged(_customBusinessTypeController.text);
  }

  void _onCustomBusinessTypeChanged(String value) {
    final String trimmed = value.trim();
    ref.read(editProfileProvider.notifier).setBusinessType(trimmed);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hydrated) {
        _hydrate(ref.read(userProfileProvider).valueOrNull);
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _kioskNameController.dispose();
    _marketLocationController.dispose();
    _customBusinessTypeController.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile? profile) {
    if (_hydrated || profile == null) {
      return;
    }
    _hydrated = true;
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phone;
    _kioskNameController.text = profile.kioskName ?? '';
    _marketLocationController.text = profile.marketLocation ?? '';
    final String? businessType = profile.businessType;
    _businessTypeSelection = _selectionFor(businessType);
    if (_businessTypeSelection == _customBusinessTypeOption) {
      _customBusinessTypeController.text = businessType ?? '';
    }
    ref.read(editProfileProvider.notifier).load(profile);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final bool succeeded = await ref
        .read(editProfileProvider.notifier)
        .submit();
    if (!mounted) {
      return;
    }
    if (succeeded) {
      AppToast.show(
        ref,
        message: 'Profil mis à jour',
        type: AppToastType.success,
      );
      Navigator.of(context).maybePop();
      return;
    }
    final String? error = ref.read(editProfileProvider).errorMessage;
    if (error != null) {
      AppToast.show(ref, message: error, type: AppToastType.error);
      ref.read(editProfileProvider.notifier).clearSubmissionResult();
    }
  }

  Future<void> _uploadAvatar() async {
    final bool succeeded = await ref
        .read(editProfileProvider.notifier)
        .uploadAvatar();
    if (!mounted) {
      return;
    }
    final String? error = ref.read(editProfileProvider).errorMessage;
    if (!succeeded && error != null) {
      AppToast.show(ref, message: error, type: AppToastType.error);
      ref.read(editProfileProvider.notifier).clearSubmissionResult();
    }
  }

  @override
  Widget build(BuildContext context) {
    final EditProfileState state = ref.watch(editProfileProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (
      AsyncValue<UserProfile?>? previous,
      AsyncValue<UserProfile?> next,
    ) {
      _hydrate(next.valueOrNull);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AvatarSection(
                  photoUrl: state.photoUrl,
                  initials: userInitials(state.fullName),
                  isUploading: state.isUploadingAvatar,
                  scheme: scheme,
                  onTap: state.isSubmitting ? null : _uploadAvatar,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: validateFullName,
                  onChanged: (String value) =>
                      ref.read(editProfileProvider.notifier).setFullName(value),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: CountryCodePicker(
                        code: state.countryCode,
                        onChanged: (String code) => ref
                            .read(editProfileProvider.notifier)
                            .setCountryCode(code),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          hintText: '07 00 00 00 00',
                        ),
                        validator: validatePhoneNumber,
                        onChanged: (String value) => ref
                            .read(editProfileProvider.notifier)
                            .setPhone(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _kioskNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nom du kiosque',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  onChanged: (String value) => ref
                      .read(editProfileProvider.notifier)
                      .setKioskName(value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _marketLocationController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Localisation / Marché',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  onChanged: (String value) => ref
                      .read(editProfileProvider.notifier)
                      .setMarketLocation(value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _businessTypeSelection,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Type d'activité",
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _presetBusinessTypes
                      .map(
                        (String type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _onBusinessTypeSelected,
                ),
                if (_showsCustomBusinessType) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _customBusinessTypeController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Précisez votre activité',
                      hintText: 'Ex: vente de Hayden',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                    onChanged: _onCustomBusinessTypeChanged,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isSubmitting || state.isUploadingAvatar
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: state.isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Text('Enregistrer les modifications'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.photoUrl,
    required this.initials,
    required this.isUploading,
    required this.scheme,
    required this.onTap,
  });

  final String? photoUrl;
  final String initials;
  final bool isUploading;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            ProfileAvatar(
              photoUrl: photoUrl,
              initials: initials,
              radius: 44,
              onTap: onTap,
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: isUploading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Icon(
                      Icons.photo_camera_outlined,
                      size: 14,
                      color: scheme.onPrimary,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: isUploading ? null : onTap,
          child: Text(isUploading ? 'Chargement…' : 'Changer la photo'),
        ),
      ],
    );
  }
}
