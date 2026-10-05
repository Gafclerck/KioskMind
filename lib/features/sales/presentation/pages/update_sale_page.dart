import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/sale.dart';
import '../providers/sales_provider.dart';

class UpdateSalePage extends ConsumerStatefulWidget {
  final Sale sale;

  const UpdateSalePage({super.key, required this.sale});

  @override
  ConsumerState<UpdateSalePage> createState() => _UpdateSalePageState();
}

class _UpdateSalePageState extends ConsumerState<UpdateSalePage> {
  late List<_SaleItemForm> _items;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _items = widget.sale.items
        .map(
          (item) => _SaleItemForm(
            item: item,
            quantityController: TextEditingController(
              text: _formatNumber(item.qty),
            ),
            priceController: TextEditingController(
              text: _formatNumber(item.unitPrice),
            ),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.quantityController.dispose();
      item.priceController.dispose();
    }
    super.dispose();
  }

  double _parse(String value) {
    return double.tryParse(
          value.replaceAll(' ', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  double get _total {
    return _items.fold(0, (sum, item) {
      final quantity = _parse(item.quantityController.text);
      final price = _parse(item.priceController.text);

      return sum + quantity * price;
    });
  }

  Future<void> _updateSale() async {
    FocusScope.of(context).unfocus();

    if (_items.isEmpty) {
      _showError('La vente doit contenir au moins un produit.');
      return;
    }

    final updatedItems = <SaleItem>[];

    for (final item in _items) {
      final quantity = _parse(item.quantityController.text);
      final price = _parse(item.priceController.text);

      if (quantity <= 0) {
        _showError(
          'La quantité de ${item.item.name} doit être supérieure à 0.',
        );
        return;
      }

      if (price < 0) {
        _showError(
          'Le prix de ${item.item.name} ne peut pas être négatif.',
        );
        return;
      }

      updatedItems.add(
        SaleItem(
          productId: item.item.productId,
          name: item.item.name,
          qty: quantity,
          unitPrice: price,
          unitCost: item.item.unitCost,
        ),
      );
    }

    final updatedSale = Sale(
      id: widget.sale.id,
      dateTime: widget.sale.dateTime,
      createdAt: widget.sale.createdAt,
      total: _total,
      items: updatedItems,
      source: widget.sale.source,
      status: widget.sale.status,
      cancelledAt: widget.sale.cancelledAt,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(updateSaleProvider)(updatedSale);

      if (!mounted) return;

      ref.invalidate(getSalesHistoryProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vente modifiée avec succès'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      _showError('Impossible de modifier la vente.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          color: colorScheme.primary,
        ),
        title: Text(
          'Modifier la vente',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vente',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(widget.sale.dateTime),
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Produits',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._items.map(
                    (item) => _SaleItemCard(
                      item: item,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${_formatNumber(_total)} FCFA',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colorScheme.secondary,
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'La modification ajustera automatiquement le stock et les statistiques de vente.',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    disabledBackgroundColor:
                        colorScheme.surfaceContainerHighest,
                    disabledForegroundColor:
                        colorScheme.onSurfaceVariant,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          'Enregistrer les modifications',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year à $hour:$minute';
  }
}

class _SaleItemForm {
  final SaleItem item;
  final TextEditingController quantityController;
  final TextEditingController priceController;

  _SaleItemForm({
    required this.item,
    required this.quantityController,
    required this.priceController,
  });
}

class _SaleItemCard extends StatelessWidget {
  final _SaleItemForm item;
  final VoidCallback onChanged;

  const _SaleItemCard({
    required this.item,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.item.name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: item.quantityController,
                  label: 'Quantité',
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  controller: item.priceController,
                  label: 'Prix unitaire',
                  suffix: 'FCFA',
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final ValueChanged<String> onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}
