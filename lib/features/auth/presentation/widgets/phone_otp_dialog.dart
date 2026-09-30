import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../providers/login_provider.dart';

class PhoneOtpDialog extends ConsumerStatefulWidget {
  const PhoneOtpDialog({super.key});

  @override
  ConsumerState<PhoneOtpDialog> createState() => _PhoneOtpDialogState();
}

class _PhoneOtpDialogState extends ConsumerState<PhoneOtpDialog> {
  static const int _digits = 6;

  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool get _isComplete => _codeController.text.length == _digits;

  Future<void> _verify() async {
    if (!_isComplete || ref.read(loginProvider).isSubmitting) {
      return;
    }
    final bool verified = await ref
        .read(loginProvider.notifier)
        .verifyPhoneOtp(_codeController.text);
    if (verified && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _resend() async {
    if (ref.read(loginProvider).isSubmitting) {
      return;
    }
    final bool sent = await ref.read(loginProvider.notifier).resendPhoneOtp();
    if (sent && mounted) {
      AppToast.show(
        ref,
        message: 'Nouveau code envoyé',
        type: AppToastType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LoginState state = ref.watch(loginProvider);
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Code de vérification'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Entrez le code à 6 chiffres envoyé par SMS au ${state.identifier}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_digits),
            ],
            style: const TextStyle(fontSize: 24, letterSpacing: 12),
            decoration: const InputDecoration(
              labelText: 'Code',
              counterText: '',
            ),
            onChanged: (String value) {
              ref.read(loginProvider.notifier).clearError();
              setState(() {});
              if (value.length == _digits) {
                _verify();
              }
            },
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(state.errorMessage!, style: TextStyle(color: AppColors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _resend, child: const Text('Renvoyer le code')),
        TextButton(
          onPressed: () {
            ref.read(loginProvider.notifier).cancelOtp();
            Navigator.of(context).pop();
          },
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: state.isSubmitting || !_isComplete ? null : _verify,
          child: state.isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Vérifier'),
        ),
      ],
    );
  }
}
