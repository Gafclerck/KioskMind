import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';
import '../widgets/feedback_dialogs.dart';
import '../widgets/product_form.dart';

class EditProductPage extends ConsumerWidget {
  const EditProductPage({super.key, required this.product});

  final Product product;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Product updated,
  ) async {
    final saved = await ref
        .read(productActionsProvider.notifier)
        .update(updated);
    if (!context.mounted) return;

    if (saved) {
      await showSuccessDialog(
        context,
        title: 'Produit mis à jour !',
        message: 'Les modifications ont été enregistrées.',
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } else {
      final retry = await showErrorDialog(
        context,
        title: 'Erreur de mise à jour',
        message:
            "Impossible d'enregistrer les modifications. Vérifiez votre connexion internet.",
      );
      if (retry && context.mounted) {
        await _save(context, ref, updated);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(productActionsProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le Produit')),
      body: ProductForm(
        initialProduct: product,
        submitLabel: 'Enregistrer les modifications',
        isLoading: isLoading,
        onSubmit: (updated) => _save(context, ref, updated),
      ),
    );
  }
}
