import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../products_stock/domain/entities/product.dart';
import '../../../products_stock/presentation/providers/product_providers.dart';
import '../../domain/entities/sale.dart';
import '../providers/sales_provider.dart';

class CreateSalePage extends ConsumerStatefulWidget {
  final List<SaleItem> items;

  const CreateSalePage({super.key, this.items = const []});

  @override
  ConsumerState<CreateSalePage> createState() => _CreateSalePageState();
}

class _CreateSalePageState extends ConsumerState<CreateSalePage> {
  final TextEditingController _searchController = TextEditingController();
  final List<_SaleLine> _saleLines = [];

  String _searchQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get total {
    return _saleLines.fold<double>(0, (sum, line) => sum + line.total);
  }

  int get totalProducts {
    return _saleLines.fold<int>(0, (sum, line) => sum + line.quantity);
  }

  void _addProduct(Product product) {
    final existingIndex = _saleLines.indexWhere(
      (line) => line.product.id == product.id,
    );

    if (existingIndex != -1) {
      final line = _saleLines[existingIndex];

      if (line.quantity >= product.quantity) {
        _showMessage(
          'Stock insuffisant pour ${product.name}.',
          isError: true,
        );
        return;
      }

      setState(() {
        line.quantity++;
      });

      return;
    }

    if (product.quantity <= 0) {
      _showMessage(
        '${product.name} est en rupture de stock.',
        isError: true,
      );
      return;
    }

    setState(() {
      _saleLines.add(_SaleLine(product: product, quantity: 1));
    });
  }

  void _increaseQuantity(_SaleLine line) {
    if (line.quantity >= line.product.quantity) {
      _showMessage('Stock disponible insuffisant.', isError: true);
      return;
    }

    setState(() {
      line.quantity++;
    });
  }

  void _decreaseQuantity(_SaleLine line) {
    if (line.quantity <= 1) {
      setState(() {
        _saleLines.remove(line);
      });
      return;
    }

    setState(() {
      line.quantity--;
    });
  }

  void _removeLine(_SaleLine line) {
    setState(() {
      _saleLines.remove(line);
    });
  }

  Future<void> _confirmSale() async {
    if (_saleLines.isEmpty) {
      _showMessage(
        'Ajoutez au moins un produit à la vente.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final saleItems = _saleLines.map((line) {
      return SaleItem(
        productId: line.product.id,
        name: line.product.name,
        qty: line.quantity.toDouble(),
        unitPrice: line.product.salePrice.toDouble(),
        unitCost: line.product.purchasePrice.toDouble(),
      );
    }).toList();

    final now = DateTime.now();

    final sale = Sale(
      dateTime: now,
      createdAt: now,
      total: total,
      items: saleItems,
      source: 'MANUAL',
      status: 'COMPLETED',
    );

    try {
      await ref.read(recordSaleProvider).call(sale);

      if (!mounted) return;

      _showMessage('Vente enregistrée avec succès.');

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Impossible d’enregistrer la vente.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? colorScheme.error : colorScheme.primary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Créer une vente',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
        ),
      ),
      body: productsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: colorScheme.primary,
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Impossible de charger les produits.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (products) {
          final filteredProducts = products.where((product) {
            if (_searchQuery.isEmpty) {
              return true;
            }

            return product.name.toLowerCase().contains(_searchQuery) ||
                product.category.toLowerCase().contains(_searchQuery);
          }).toList();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchField(),

                      const SizedBox(height: 24),

                      if (_saleLines.isNotEmpty) ...[
                        _buildSectionTitle(
                          'Produits sélectionnés',
                          '${_saleLines.length}',
                        ),
                        const SizedBox(height: 12),
                        ..._saleLines.map((line) => _buildSaleLine(line)),
                        const SizedBox(height: 28),
                      ],

                      _buildSectionTitle(
                        'Produits',
                        '${filteredProducts.length}',
                      ),

                      const SizedBox(height: 12),

                      if (filteredProducts.isEmpty)
                        _buildEmptyProducts()
                      else
                        ...filteredProducts.map(
                          (product) => _buildProductCard(product),
                        ),
                    ],
                  ),
                ),
              ),
              _buildBottomSummary(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un produit...',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colorScheme.primary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String count) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final colorScheme = Theme.of(context).colorScheme;

    final selectedIndex = _saleLines.indexWhere(
      (line) => line.product.id == product.id,
    );

    final isSelected = selectedIndex != -1;

    final selectedQuantity = isSelected
        ? _saleLines[selectedIndex].quantity
        : 0;

    final isOutOfStock = product.quantity <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                ),

                const SizedBox(height: 5),

                Text(
                  product.category,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                      ),
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    Text(
                      '${product.salePrice} FCFA',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Text(
                      'Stock : ${product.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOutOfStock
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          if (isSelected)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$selectedQuantity',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

          const SizedBox(width: 6),

          IconButton(
            onPressed: isOutOfStock
                ? null
                : () => _addProduct(product),
            style: IconButton.styleFrom(
              backgroundColor: isOutOfStock
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.primary,
            ),
            icon: Icon(
              Icons.add_rounded,
              color: isOutOfStock
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleLine(_SaleLine line) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.product.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),

              IconButton(
                onPressed: () => _removeLine(line),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Text(
                '${line.product.salePrice} FCFA / ${line.product.unit}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),

              const Spacer(),

              IconButton(
                onPressed: () => _decreaseQuantity(line),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  minimumSize: const Size(36, 36),
                ),
                icon: Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),

              SizedBox(
                width: 42,
                child: Center(
                  child: Text(
                    '${line.quantity}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),

              IconButton(
                onPressed: () => _increaseQuantity(line),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  minimumSize: const Size(36, 36),
                ),
                icon: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Text(
                'Sous-total',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),

              const Spacer(),

              Text(
                '${line.total.toStringAsFixed(0)} FCFA',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProducts() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 42,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun produit trouvé',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSummary() {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant,
            ),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 15,
              offset: const Offset(0, -4),
              color: Colors.black.withValues(alpha: 0.04),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const Spacer(),

                Text(
                  '${total.toStringAsFixed(0)} FCFA',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$totalProducts article${totalProducts > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saleLines.isEmpty || _isSaving
                    ? null
                    : _confirmSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  disabledBackgroundColor:
                      colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Confirmer la vente',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleLine {
  final Product product;
  int quantity;

  _SaleLine({
    required this.product,
    required this.quantity,
  });

  double get total {
    return quantity.toDouble() * product.salePrice.toDouble();
  }
}