import 'package:flutter/material.dart';

Future<void> showSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.check_circle_outline,
        color: Theme.of(context).colorScheme.primary,
        size: 40,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<bool> showErrorDialog(
  BuildContext context, {
  String title = 'Erreur de connexion',
  String message =
      'Impossible de synchroniser. Vérifiez votre connexion internet.',
}) async {
  final retry = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
        size: 40,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Réessayer'),
        ),
      ],
    ),
  );
  return retry ?? false;
}
