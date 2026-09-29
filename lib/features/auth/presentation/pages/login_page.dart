import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_validators.dart';
import '../controllers/login_controller.dart';
import 'signup_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion bientôt disponible')),
      );
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réinitialisation bientôt disponible')),
    );
  }

  void _goToSignup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SignupPage()));
  }

  @override
  Widget build(BuildContext context) {
    final LoginState state = ref.watch(loginControllerProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bon retour !',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous à votre copilote KioskMind',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _identifierController,
                  keyboardType: state.emailMode
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: state.emailMode
                        ? 'Adresse e-mail'
                        : 'Numéro de téléphone',
                    hintText: state.emailMode
                        ? 'nom@exemple.com'
                        : '+225 07 00 00 00 00',
                    prefixIcon: Icon(
                      state.emailMode
                          ? Icons.alternate_email_outlined
                          : Icons.phone_outlined,
                    ),
                  ),
                  validator: (String? value) => state.emailMode
                      ? validateEmail(value)
                      : validatePhoneNumber(value),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ref
                        .read(loginControllerProvider.notifier)
                        .toggleIdentifierMode(),
                    child: Text(
                      state.emailMode
                          ? "Utiliser le téléphone"
                          : "Utiliser l'e-mail",
                    ),
                  ),
                ),
                TextFormField(
                  controller: _passwordController,
                  obscureText: state.obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => ref
                          .read(loginControllerProvider.notifier)
                          .togglePasswordVisibility(),
                      icon: Icon(
                        state.obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Mot de passe oublié ?'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Se connecter'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pas encore de compte ?',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _goToSignup,
                      child: const Text("S'inscrire"),
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
