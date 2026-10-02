import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/ports/handler_call_journal.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../catalog/in_memory_product_catalog.dart';
import '../journaling_intent_handler.dart';
import 'mock_cancel_last_sale_handler.dart';
import 'mock_query_stock_handler.dart';
import 'mock_record_restock_handler.dart';
import 'mock_record_sale_handler.dart';

/// Builds the in-memory handlers, each wrapped so every call is recorded.
///
/// Kept after the real use cases are integrated: they then remain the
/// demonstration and test doubles of the demo scenario.
VoiceHandlers buildMockVoiceHandlers({
  required InMemoryProductCatalog catalog,
  required HandlerCallJournal journal,
}) {
  return VoiceHandlers(
    recordSale: JournalingIntentHandler<SaleIntentInput, RecordSaleResult>(
      MockRecordSaleHandler(catalog),
      journal,
    ),
    recordRestock:
        JournalingIntentHandler<RestockIntentInput, RecordRestockResult>(
          MockRecordRestockHandler(catalog),
          journal,
        ),
    queryStock: JournalingIntentHandler<QueryStockInput, QueryStockResult>(
      MockQueryStockHandler(catalog),
      journal,
    ),
    cancelLastSale:
        JournalingIntentHandler<CancelLastSaleInput, CancelLastSaleResult>(
          MockCancelLastSaleHandler(catalog),
          journal,
        ),
  );
}
