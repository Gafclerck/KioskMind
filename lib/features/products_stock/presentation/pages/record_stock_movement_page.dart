import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/usecases/record_stock_movement.dart';
import '../providers/product_providers.dart';
import '../widgets/feedback_dialogs.dart';
import '../widgets/formatters.dart';

/// UC7 et UC8 : une entrée ou une sortie de stock.
///
/// La différence entre les deux tient au type et au motif du mouvement, pas à
/// deux écrans séparés : le vendeur choisit Entrée ou Sortie puis le motif.
class RecordStockMovementPage extends ConsumerStatefulWidget {
  const RecordStockMovementPage({
    super.key,
    required this.product,
    this.initialDirection = StockMovementDirection.inbound,
  });

  final Product product;
  final StockMovementDirection initialDirection;

  @override
  ConsumerState<RecordStockMovementPage> createState() =>
      _RecordStockMovementPageState();
}

enum StockMovementDirection {
  inbound('Entrée', 'Achat / Réapprovisionnement'),
  outbound('Sortie', 'Perte, casse ou don');

  const StockMovementDirection(this.label, this.subtitle);

  final String label;
  final String subtitle;
}

class _RecordStockMovementPageState
    extends ConsumerState<RecordStockMovementPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  late StockMovementDirection _direction;
  late StockMovementReason _reason;

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
    _reason = _defaultReasonFor(_direction);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  StockMovementReason _defaultReasonFor(StockMovementDirection direction) =>
      direction == StockMovementDirection.inbound
      ? StockMovementReason.purchase
      : StockMovementReason.loss;

  List<StockMovementReason> get _reasons =>
      _direction == StockMovementDirection.inbound
      ? const [StockMovementReason.purchase]
      : const [
          StockMovementReason.loss,
          StockMovementReason.breakage,
          StockMovementReason.donation,
          StockMovementReason.manualAdjustment,
        ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final movement = StockMovement(
      id: '',
      productId: widget.product.id,
      type: _direction == StockMovementDirection.inbound
          ? StockMovementType.purchase
          : StockMovementType.manualOut,
      reason: _reason,
      quantity: int.parse(_quantityController.text.trim()),
      createdAt: DateTime.now().toUtc(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    final notifier = ref.read(stockMovementActionsProvider.notifier);
    final succeeded = _direction == StockMovementDirection.inbound
        ? await notifier.recordIn(movement)
        : await notifier.recordOut(movement);
    if (!mounted) return;

    final failure = ref.read(stockMovementActionsProvider).error;
    if (succeeded) {
      await showSuccessDialog(
        context,
        title: _direction == StockMovementDirection.inbound
            ? 'Entrée enregistrée !'
            : 'Sortie enregistrée !',
        message: _direction == StockMovementDirection.inbound
            ? '${formatUnit(movement.quantity, widget.product.unit)} ajoutés au stock.'
            : '${formatUnit(movement.quantity, widget.product.unit)} retirés du stock.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else if (failure is StockMovementFailure) {
      await showErrorDialog(
        context,
        title: 'Stock insuffisant',
        message: failure.message,
      );
    } else {
      final retry = await showErrorDialog(context);
      if (retry && mounted) {
        await _submit();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(stockMovementActionsProvider).isLoading;
    final isInbound = _direction == StockMovementDirection.inbound;
    final unit = formatUnit(widget.product.quantity, widget.product.unit);

    return Scaffold(
      appBar: AppBar(
        title: Text(isInbound ? 'Entrée de stock' : 'Sortie de stock'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Stock actuel : ${widget.product.quantity} $unit',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<StockMovementDirection>(
                    segments: [
                      for (final direction in StockMovementDirection.values)
                        ButtonSegment(
                          value: direction,
                          label: Text(direction.label),
                        ),
                    ],
                    selected: {_direction},
                    onSelectionChanged: (selection) => setState(() {
                      _direction = selection.first;
                      _reason = _defaultReasonFor(_direction);
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _direction.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey<String>('movement_quantity'),
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantité',
                      hintText: 'Ex: 12',
                      suffixText: widget.product.unit,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null) return 'Saisissez un nombre';
                      if (parsed <= 0) {
                        return 'La quantité doit être supérieure à zéro';
                      }
                      if (!isInbound && parsed > widget.product.quantity) {
                        return 'Stock insuffisant (${widget.product.quantity})';
                      }
                      return null;
                    },
                  ),
                  if (!isInbound) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<StockMovementReason>(
                      initialValue: _reason,
                      decoration: const InputDecoration(labelText: 'Motif'),
                      items: [
                        for (final reason in _reasons)
                          DropdownMenuItem(
                            value: reason,
                            child: Text(_reasonLabel(reason)),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _reason = value ?? _reason),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey<String>('movement_note'),
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (Optionnel)',
                      hintText: 'Ex: Livraison du fournisseur M. Diallo',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey<String>('movement_submit'),
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isInbound ? 'Valider l\'entrée' : 'Valider la sortie',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _reasonLabel(StockMovementReason reason) => switch (reason) {
    StockMovementReason.purchase => 'Achat fournisseur',
    StockMovementReason.sale => 'Vente',
    StockMovementReason.loss => 'Perte',
    StockMovementReason.breakage => 'Casse',
    StockMovementReason.donation => 'Don',
    StockMovementReason.manualAdjustment => 'Ajustement manuel',
  };
}
