import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../domain/constants/product_options.dart';
import '../../domain/entities/product.dart';
import '../../domain/services/product_image_upload_service.dart';
import '../providers/product_image_upload_service_provider.dart';
import 'product_image.dart';

class ProductForm extends ConsumerStatefulWidget {
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
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _alertThreshold;
  late String _category;
  late String _unit;
  late int _quantity;

  /// Photo déjà enregistrée, ou en cours d'envoi. Volontairement pas un
  /// contrôleur : l'utilisateur ne saisit plus d'URL, il choisit une image.
  String? _imageUrl;
  bool _isUploadingImage = false;

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
    _imageUrl = p?.imageUrl;
    // L'initiale de la photo est reprise du nom : elle doit suivre la saisie.
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
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

  /// Ouvre la galerie et téléverse la photo choisie. L'upload part dès la
  /// sélection : le document produit n'existe pas encore à la création, et
  /// attendre l'enregistrement ferait perdre la photo en cas d'échec.
  Future<void> _pickImage() async {
    if (_isUploadingImage) {
      return;
    }
    setState(() => _isUploadingImage = true);

    String? url;
    String? error;
    try {
      url = await ref.read(productImageUploadServiceProvider).pickAndUpload();
    } on ProductImageUploadException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Impossible de téléverser la photo, réessayez';
    }

    if (!mounted) {
      return;
    }
    setState(() => _isUploadingImage = false);
    if (error != null) {
      AppToast.show(ref, message: error, type: AppToastType.error);
      return;
    }
    // null : l'utilisateur a annulé la galerie, on ne touche à rien.
    if (url != null) {
      setState(() => _imageUrl = url);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSubmit(
      Product(
        id: widget.initialProduct?.id ?? '',
        name: _name.text.trim(),
        imageUrl: _imageUrl,
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
                  key: const ValueKey<String>('product_form_name'),
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
                    ProductImage(
                      key: const ValueKey<String>('product_form_photo'),
                      name: _name.text,
                      imageUrl: _imageUrl,
                      radius: 28,
                      isBusy: _isUploadingImage,
                      onTap: _pickImage,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('product_form_pick_photo'),
                        onPressed: _isUploadingImage
                            ? null
                            : () => _pickImage(),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _isUploadingImage
                              ? 'Téléversement…'
                              : _imageUrl == null
                              ? 'Choisir une photo'
                              : 'Changer la photo',
                        ),
                      ),
                    ),
                  ],
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
                        key: const ValueKey<String>(
                          'product_form_purchase_price',
                        ),
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
                        key: const ValueKey<String>('product_form_sale_price'),
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
                Text(
                  _isCreation ? 'Quantité initiale' : 'Quantité en rayon',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  _isCreation
                      ? 'Actuellement en rayon'
                      : 'Ajustement direct du niveau de stock',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _quantity > 0
                          ? () => setState(() => _quantity--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey<String>('product_form_alert_threshold'),
                  controller: _alertThreshold,
                  decoration: InputDecoration(
                    labelText: "Seuil d'alerte critique",
                    helperText:
                        'Alerter quand le stock est inférieur à ${_alertThreshold.text} ${_unit.toLowerCase()}',
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
