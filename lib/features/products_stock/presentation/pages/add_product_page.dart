import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';
import '../widgets/feedback_dialogs.dart';
import '../widgets/product_form.dart';

class AddProductPage extends ConsumerWidget {
  const AddProductPage({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final saved = await ref
        .read(productActionsProvider.notifier)
        .create(product);
    if (!context.mounted) return;

    if (saved) {
      await showSuccessDialog(
        context,
        title: 'Produit ajouté avec succès !',
        message: "L'inventaire a été mis à jour correctement.",
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } else {
      final retry = await showErrorDialog(context);
      if (retry && context.mounted) {
        await _save(context, ref, product);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(productActionsProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau Produit')),
      body: ProductForm(
        submitLabel: 'Enregistrer le Produit',
        isLoading: isLoading,
        onSubmit: (product) => _save(context, ref, product),
      ),
    );
  }
}
