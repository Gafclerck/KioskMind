import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/constants/product_options.dart';
import '../../domain/entities/product.dart';

class ProductForm extends StatefulWidget {
  const ProductForm({
    super.key,
    this.initialProduct,
    required this.submitLabel,
    required this.isLoading,
    required this.onSubmit,
  });

  final Product? initialProduct;
  final String submitLabel;
  final bool isLoading;
  final void Function(Product product) onSubmit;

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _alertThreshold;
  late String _category;
  late String _unit;
  late int _quantity;

  bool get _isCreation => widget.initialProduct == null;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    _name = TextEditingController(text: p?.name ?? '');
    _purchasePrice = TextEditingController(
      text: p?.purchasePrice.toString() ?? '',
    );
    _salePrice = TextEditingController(text: p?.salePrice.toString() ?? '');
    _alertThreshold = TextEditingController(
      text: p?.alertThreshold.toString() ?? '',
    );
    _category = p?.category ?? productCategories.first;
    _unit = p?.unit ?? productUnits.first;
    _quantity = p?.quantity ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _purchasePrice.dispose();
    _salePrice.dispose();
    _alertThreshold.dispose();
    super.dispose();
  }

  String? _requiredText(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

  String? _requiredNumber(String? value) =>
      int.tryParse(value?.trim() ?? '') == null ? 'Saisissez un nombre' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSubmit(
      Product(
        id: widget.initialProduct?.id ?? '',
        name: _name.text.trim(),
        imageUrl: widget.initialProduct?.imageUrl,
        category: _category,
        unit: _unit,
        purchasePrice: int.parse(_purchasePrice.text.trim()),
        salePrice: int.parse(_salePrice.text.trim()),
        quantity: _quantity,
        alertThreshold: int.parse(_alertThreshold.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nom du produit *',
                    hintText: 'Ex: Sac de Riz Royal 5kg',
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie',
                        ),
                        items: [
                          for (final c in productCategories)
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(labelText: 'Unité'),
                        items: [
                          for (final u in productUnits)
                            DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: (v) => setState(() => _unit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePrice,
                        decoration: const InputDecoration(
                          labelText: "Prix d'achat (FCFA)",
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _requiredNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _salePrice,
                        decoration: const InputDecoration(
                          labelText: 'Prix de vente (FCFA)',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _requiredNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isCreation) ...[
                  Row(
                    children: [
                      const Expanded(child: Text('Quantité initiale')),
                      IconButton(
                        onPressed: _quantity > 0
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$_quantity'),
                      IconButton(
                        onPressed: () => setState(() => _quantity++),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _alertThreshold,
                  decoration: const InputDecoration(
                    labelText: "Seuil d'alerte critique",
                    helperText:
                        'Alerter quand le stock est inférieur à ce nombre',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _requiredNumber,
                ),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.isLoading ? null : _submit,
                child: widget.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.submitLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
