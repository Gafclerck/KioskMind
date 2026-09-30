import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_validators.dart';
import '../../domain/country_codes.dart';
import '../providers/signup_provider.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inscription bientôt disponible')),
      );
    }
  }

  void _goToLogin() {
    Navigator.of(context).maybePop();
  }

  void _googleSignUp() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Google bientôt disponible')));
  }

  @override
  Widget build(BuildContext context) {
    final SignupState state = ref.watch(signupProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Rejoignez KioskMind pour piloter votre commerce',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 128,
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey<String>('country_code'),
                        initialValue: state.countryCode,
                        items: countryCodes
                            .map(
                              (CountryCode country) => DropdownMenuItem<String>(
                                value: country.code,
                                child: Text(country.code),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            ref
                                .read(signupProvider.notifier)
                                .selectCountryCode(value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Indicatif',
                        ),
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: state.obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => ref
                          .read(signupProvider.notifier)
                          .togglePasswordVisibility(),
                      icon: Icon(
                        state.obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: validatePassword,
                  onChanged: (String value) =>
                      ref.read(signupProvider.notifier).setPassword(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmationController,
                  obscureText: state.obscureConfirmation,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => ref
                          .read(signupProvider.notifier)
                          .toggleConfirmationVisibility(),
                      icon: Icon(
                        state.obscureConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (String? value) =>
                      validatePasswordConfirmation(state.password, value),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                FormField<bool>(
                  initialValue: state.acceptedTerms,
                  validator: validateTermsAccepted,
                  builder: (FormFieldState<bool> field) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          value: field.value ?? false,
                          onChanged: (bool? value) {
                            field.didChange(value ?? false);
                            ref
                                .read(signupProvider.notifier)
                                .setAcceptedTerms(value ?? false);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text.rich(
                            TextSpan(
                              style: theme.textTheme.bodyMedium,
                              children: <InlineSpan>[
                                const TextSpan(text: "J'accepte les "),
                                TextSpan(
                                  text: "Conditions d'Utilisation",
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' et la '),
                                TextSpan(
                                  text: 'Politique de Confidentialité',
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 4),
                            child: Text(
                              field.errorText!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Créer mon compte'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _googleSignUp,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.g_mobiledata_outlined, size: 28),
                  label: const Text("S'inscrire avec Google"),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Déjà un compte ?', style: theme.textTheme.bodyMedium),
                    TextButton(
                      onPressed: _goToLogin,
                      child: const Text('Se connecter'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
