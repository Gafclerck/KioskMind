import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/voice_flags.dart';
import '../../../core/voice_services/device_speech_recognizer.dart';
import '../../../core/voice_services/device_speech_speaker.dart';
import '../../../core/voice_services/platform_speech_recognizer.dart';
import '../../../core/voice_services/platform_tts.dart';
import '../../../core/voice_services/speech_recognizer_port.dart';
import '../../../core/voice_services/tts_port.dart';
import '../../../core/voice_services/voice_service_settings.dart';
import '../../../features/export_reporting/presentation/providers/export_providers.dart';
import '../../../features/navigation/navigation_index_provider.dart';
import '../../../features/products_stock/presentation/providers/product_providers.dart';
import '../../../features/sales/presentation/providers/sales_provider.dart';
import '../data/catalog/catalog_fixture_loader.dart';
import '../data/catalog/in_memory_product_catalog.dart';
import '../data/catalog/intent_catalog_loader.dart';
import '../data/catalog/product_resolver.dart';
import '../data/catalog/real_product_catalog_reader.dart';
import '../data/clock/system_voice_clock.dart';
import '../data/commands/session_command_ids.dart';
import '../data/commands/voice_bindings.dart';
import '../data/connectivity/data_connection_probe.dart';
import '../data/extractors/item_list_extractor.dart';
import '../data/extractors/line_extractor.dart';
import '../data/extractors/product_name_resolver.dart';
import '../data/formulator/ai_message_formulator.dart';
import '../data/formulator/cascading_message_formulator.dart';
import '../data/formulator/offline_natural_formulator.dart';
import '../data/handlers/call_journal.dart';
import '../data/handlers/journaling_intent_handler.dart';
import '../data/handlers/mock/mock_voice_handlers.dart';
import '../data/handlers/real/real_cancel_last_sale_handler.dart';
import '../data/handlers/real/real_create_product_handler.dart';
import '../data/handlers/real/real_export_report_handler.dart';
import '../data/handlers/real/real_navigate_handler.dart';
import '../data/handlers/real/real_query_business_info_handler.dart';
import '../data/handlers/real/real_query_daily_stats_handler.dart';
import '../data/handlers/real/real_query_low_stock_handler.dart';
import '../data/handlers/real/real_query_product_price_handler.dart';
import '../data/handlers/real/real_query_sales_history_handler.dart';
import '../data/handlers/real/real_query_stock_handler.dart';
import '../data/handlers/real/real_record_restock_handler.dart';
import '../data/handlers/real/real_record_sale_handler.dart';
import '../data/handlers/real/real_record_stock_out_handler.dart';
import '../data/handlers/real/real_update_product_price_handler.dart';
import '../data/parsers/direct_gemini_caller.dart';
import '../data/parsers/remote_cloud_intent_parser.dart';
import '../data/parsers/rodium_ai_caller.dart';
import '../data/parsers/rule_based_parser.dart';
import '../domain/dialog/dialog_manager.dart';
import '../domain/ports/message_formulator.dart';
import '../domain/registry/kiosk_registry.dart';
import '../domain/registry/kiosk_tool_spec.dart';
import '../domain/entities/fact_result.dart';
import '../domain/entities/intent_definition.dart';
import '../domain/entities/intent_input.dart';
import '../domain/entities/intent_result.dart';
import '../domain/entities/product_snapshot.dart';
import '../domain/entities/voice_config.dart';
import '../domain/ports/cloud_intent_parser.dart';
import '../domain/ports/command_id_factory.dart';
import '../domain/ports/connectivity_probe.dart';
import '../domain/ports/handler_call_journal.dart';
import '../domain/ports/intent_handler.dart';
import '../domain/ports/intent_parser.dart';
import '../domain/ports/intent_registry.dart';
import '../domain/ports/product_catalog_reader.dart';
import '../domain/ports/spoken_product_resolver.dart';
import '../domain/ports/voice_clock.dart';
import '../domain/services/answer_application.dart';
import '../domain/services/answer_reading.dart';
import '../domain/services/cascading_parser.dart';
import '../domain/services/circuit_breaker.dart';
import '../domain/services/command_validator.dart';
import '../domain/services/decision_policy.dart';
import '../domain/services/french_number_parser.dart';
import '../domain/services/intent_detector.dart';
import '../domain/services/text_normalizer.dart';
import '../domain/usecases/execute_command.dart';
import '../domain/usecases/handle_utterance.dart';
import '../domain/usecases/undo_last_command.dart';

/// Composition root of the voice module.
///
/// It is the single place that knows whether a handler is the in-memory mock or
/// the real use case, so the rest of the module never branches on that choice.
/// It lives inside the feature rather than in `core/di` because `core/` is
/// reserved for code two features or more share, and a core module must not
/// depend on a feature: wiring voice handlers from there would break both rules.
/// `core/di` stays free for genuinely cross-feature wiring.
///
/// This is not a fourth layer. It only assembles `domain` and `data`; the
/// `presentation` layer consumes the providers declared here and never imports
/// `data/` itself.

/// Whether the composition root wires the in-memory handlers.
///
/// Reads the build-time flag, and can be overridden per provider in tests, so
/// phase I can switch one intent at a time.
final Provider<bool> voiceUseMocksProvider = Provider<bool>(
  (Ref ref) => kVoiceUseMocks,
);

/// Where handler calls are recorded, for the routing metric and the tests.
final Provider<HandlerCallJournal> voiceCallJournalProvider =
    Provider<HandlerCallJournal>((Ref ref) => InMemoryCallJournal());

/// The product catalog the mocks work on, read from the bundled fixture.
final FutureProvider<InMemoryProductCatalog> voiceMockCatalogProvider =
    FutureProvider<InMemoryProductCatalog>((Ref ref) async {
      final String source = await rootBundle.loadString(catalogFixtureAsset);
      return InMemoryProductCatalog(parseCatalogFixture(source));
    });

/// The real product catalog reader, reading products from products_stock feature.
final Provider<ProductCatalogReader> voiceRealProductCatalogReaderProvider =
    Provider<ProductCatalogReader>((Ref ref) {
      return RealProductCatalogReader(ref.watch(productRepositoryProvider));
    });

/// Active catalog reader:
/// Uses mock fixture when voiceUseMocksProvider is true, or real products when false.
final FutureProvider<ProductCatalogReader> voiceCatalogReaderProvider =
    FutureProvider<ProductCatalogReader>((Ref ref) async {
      if (ref.watch(voiceUseMocksProvider)) {
        return ref.watch(voiceMockCatalogProvider.future);
      }
      return ref.watch(voiceRealProductCatalogReaderProvider);
    });

/// The real sale handler, calling the sales usecase.
final FutureProvider<RecordSaleHandler> voiceRealRecordSaleHandlerProvider =
    FutureProvider<RecordSaleHandler>((Ref ref) async {
      return RealRecordSaleHandler(
        recordSale: ref.watch(recordSaleProvider),
        catalogReader: await ref.watch(voiceCatalogReaderProvider.future),
      );
    });

/// The real cancel sale handler, calling the sales usecase.
final FutureProvider<CancelLastSaleHandler>
voiceRealCancelLastSaleHandlerProvider = FutureProvider<CancelLastSaleHandler>((
  Ref ref,
) async {
  return RealCancelLastSaleHandler(
    cancelSale: ref.watch(cancelSaleProvider),
    catalogReader: await ref.watch(voiceCatalogReaderProvider.future),
  );
});

/// The real query stock handler, reading the product catalog.
final FutureProvider<QueryStockHandler> voiceRealQueryStockHandlerProvider =
    FutureProvider<QueryStockHandler>((Ref ref) async {
      return RealQueryStockHandler(
        await ref.watch(voiceCatalogReaderProvider.future),
      );
    });

/// The real restock handler, calling the products_stock feature.
final FutureProvider<RecordRestockHandler>
voiceRealRecordRestockHandlerProvider = FutureProvider<RecordRestockHandler>((
  Ref ref,
) async {
  return RealRecordRestockHandler(
    recordStockIn: ref.watch(recordStockInProvider),
    catalogReader: await ref.watch(voiceCatalogReaderProvider.future),
  );
});

final FutureProvider<QueryDailyStatsHandler>
voiceRealQueryDailyStatsHandlerProvider =
    FutureProvider<QueryDailyStatsHandler>((Ref ref) async {
      return RealQueryDailyStatsHandler(ref.watch(getSalesDashboardProvider));
    });

final FutureProvider<QueryLowStockHandler>
voiceRealQueryLowStockHandlerProvider = FutureProvider<QueryLowStockHandler>((
  Ref ref,
) async {
  return RealQueryLowStockHandler(
    await ref.watch(voiceCatalogReaderProvider.future),
  );
});

final FutureProvider<QueryProductPriceHandler>
voiceRealQueryProductPriceHandlerProvider =
    FutureProvider<QueryProductPriceHandler>((Ref ref) async {
      return RealQueryProductPriceHandler(
        await ref.watch(voiceCatalogReaderProvider.future),
      );
    });

final FutureProvider<RecordStockOutHandler>
voiceRealRecordStockOutHandlerProvider = FutureProvider<RecordStockOutHandler>((
  Ref ref,
) async {
  return RealRecordStockOutHandler(
    recordStockOut: ref.watch(recordStockOutProvider),
    catalogReader: await ref.watch(voiceCatalogReaderProvider.future),
  );
});

final Provider<NavigateToPageHandler> voiceRealNavigateHandlerProvider =
    Provider<NavigateToPageHandler>((Ref ref) {
      return RealNavigateHandler(
        navigator: (int tabIndex, String destination) {
          ref.read(navigationIndexProvider.notifier).goTo(tabIndex);
        },
      );
    });

final FutureProvider<ExportSalesReportHandler>
voiceRealExportReportHandlerProvider = FutureProvider<ExportSalesReportHandler>(
  (Ref ref) async {
    return RealExportReportHandler(
      exportGenerator: ref.watch(salesExportGeneratorProvider),
      shareGateway: ref.watch(shareExportGatewayProvider),
      getSalesHistory: ref.watch(getSalesHistoryProvider),
      productRepository: ref.watch(productRepositoryProvider),
    );
  },
);

final FutureProvider<CreateProductHandler>
voiceRealCreateProductHandlerProvider = FutureProvider<CreateProductHandler>((
  Ref ref,
) async {
  return RealCreateProductHandler(
    createProduct: ref.watch(createProductProvider),
  );
});

final FutureProvider<UpdateProductPriceHandler>
voiceRealUpdateProductPriceHandlerProvider =
    FutureProvider<UpdateProductPriceHandler>((Ref ref) async {
      return RealUpdateProductPriceHandler(
        updateProduct: ref.watch(updateProductProvider),
        productRepository: ref.watch(productRepositoryProvider),
        catalogReader: await ref.watch(voiceCatalogReaderProvider.future),
      );
    });

final FutureProvider<QuerySalesHistoryHandler>
voiceRealQuerySalesHistoryHandlerProvider =
    FutureProvider<QuerySalesHistoryHandler>((Ref ref) async {
      return RealQuerySalesHistoryHandler(ref.watch(getSalesHistoryProvider));
    });

final FutureProvider<QueryBusinessInfoHandler>
voiceRealQueryBusinessInfoHandlerProvider =
    FutureProvider<QueryBusinessInfoHandler>((Ref ref) async {
      return RealQueryBusinessInfoHandler(
        catalogReader: await ref.watch(voiceCatalogReaderProvider.future),
        getSalesHistory: ref.watch(getSalesHistoryProvider),
      );
    });

/// The handlers the executor will call.
///
/// Dispatches to real feature handlers when VOICE_USE_MOCKS=false, or to
/// mock handlers when VOICE_USE_MOCKS=true.
final FutureProvider<VoiceHandlers>
voiceHandlersProvider = FutureProvider<VoiceHandlers>((Ref ref) async {
  final HandlerCallJournal journal = ref.watch(voiceCallJournalProvider);
  if (!ref.watch(voiceUseMocksProvider)) {
    return VoiceHandlers(
      recordSale: JournalingIntentHandler<SaleIntentInput, RecordSaleResult>(
        await ref.watch(voiceRealRecordSaleHandlerProvider.future),
        journal,
      ),
      recordRestock:
          JournalingIntentHandler<RestockIntentInput, RecordRestockResult>(
            await ref.watch(voiceRealRecordRestockHandlerProvider.future),
            journal,
          ),
      queryStock: JournalingIntentHandler<QueryStockInput, QueryStockResult>(
        await ref.watch(voiceRealQueryStockHandlerProvider.future),
        journal,
      ),
      cancelLastSale:
          JournalingIntentHandler<CancelLastSaleInput, CancelLastSaleResult>(
            await ref.watch(voiceRealCancelLastSaleHandlerProvider.future),
            journal,
          ),
      queryDailyStats:
          JournalingIntentHandler<QueryDailyStatsInput, QueryDailyStatsResult>(
            await ref.watch(voiceRealQueryDailyStatsHandlerProvider.future),
            journal,
          ),
      queryLowStock:
          JournalingIntentHandler<QueryLowStockInput, QueryLowStockResult>(
            await ref.watch(voiceRealQueryLowStockHandlerProvider.future),
            journal,
          ),
      queryProductPrice:
          JournalingIntentHandler<
            QueryProductPriceInput,
            QueryProductPriceResult
          >(
            await ref.watch(voiceRealQueryProductPriceHandlerProvider.future),
            journal,
          ),
      recordStockOut:
          JournalingIntentHandler<RecordStockOutInput, RecordStockOutResult>(
            await ref.watch(voiceRealRecordStockOutHandlerProvider.future),
            journal,
          ),
      navigateToPage:
          JournalingIntentHandler<NavigateToPageInput, NavigateToPageResult>(
            ref.watch(voiceRealNavigateHandlerProvider),
            journal,
          ),
      exportSalesReport:
          JournalingIntentHandler<
            ExportSalesReportInput,
            ExportSalesReportResult
          >(
            await ref.watch(voiceRealExportReportHandlerProvider.future),
            journal,
          ),
      createProduct:
          JournalingIntentHandler<CreateProductInput, CreateProductResult>(
            await ref.watch(voiceRealCreateProductHandlerProvider.future),
            journal,
          ),
      updateProductPrice:
          JournalingIntentHandler<
            UpdateProductPriceInput,
            UpdateProductPriceResult
          >(
            await ref.watch(voiceRealUpdateProductPriceHandlerProvider.future),
            journal,
          ),
      querySalesHistory:
          JournalingIntentHandler<
            QuerySalesHistoryInput,
            QuerySalesHistoryResult
          >(
            await ref.watch(voiceRealQuerySalesHistoryHandlerProvider.future),
            journal,
          ),
      queryBusinessInfo:
          JournalingIntentHandler<
            QueryBusinessInfoInput,
            QueryBusinessInfoResult
          >(
            await ref.watch(voiceRealQueryBusinessInfoHandlerProvider.future),
            journal,
          ),
    );
  }
  return buildMockVoiceHandlers(
    catalog: await ref.watch(voiceMockCatalogProvider.future),
    journal: journal,
  );
});

/// The tunables, in one place so a test can replace all of them at once.
final Provider<VoiceConfig> voiceConfigProvider = Provider<VoiceConfig>(
  (Ref ref) => const VoiceConfig(),
);

/// The intent catalog, read from the bundled asset.
///
/// One instance per container: the catalog is validated on load and holds the risk
/// of every intent, which is what the decision policy reads.
final FutureProvider<IntentCatalog> voiceIntentsProvider =
    FutureProvider<IntentCatalog>(
      (Ref ref) async =>
          parseIntentCatalog(await rootBundle.loadString(intentCatalogAsset)),
    );

/// The device clock. Overridden wherever time must not pass.
final Provider<VoiceClock> voiceClockProvider = Provider<VoiceClock>(
  (Ref ref) => const SystemVoiceClock(),
);

/// Command identifiers, one sequence per container so a replay does not collide.
final Provider<CommandIdFactory> voiceCommandIdsProvider =
    Provider<CommandIdFactory>(
      (Ref ref) => SessionCommandIds(clock: ref.watch(voiceClockProvider)),
    );

/// The session state: the pending question, the undo window, the turn count.
///
/// One instance per container, because the session is what a second utterance reads.
/// A container per session is the presentation layer's business, and overriding this
/// provider is how a test replaces the whole session.
final Provider<DialogManager> voiceDialogProvider = Provider<DialogManager>(
  (Ref ref) => DialogManager(
    config: ref.watch(voiceConfigProvider),
    clock: ref.watch(voiceClockProvider),
  ),
);

/// What the module doubts on its own: a quantity or a price the catalog contradicts.
///
/// Reads the catalog rather than a list of intent names: which price an announced
/// amount is compared against is declared per intent, so a new command needs no
/// change here.
final FutureProvider<CommandValidator> voiceCommandValidatorProvider =
    FutureProvider<CommandValidator>(
      (Ref ref) async => CommandValidator(
        config: ref.watch(voiceConfigProvider),
        intents: await ref.watch(voiceIntentsProvider.future),
      ),
    );

/// Every command the module can run, indexed by intent.
///
/// The registry and the catalog must agree, and it is checked here because this is
/// the only place that knows both: a command described but unbound would be
/// understood and then refused as a wiring error, and a command bound but
/// undescribed would be reachable without the parser or the test set knowing it.
final FutureProvider<IntentRegistry> voiceIntentRegistryProvider =
    FutureProvider<IntentRegistry>((Ref ref) async {
      final IntentRegistry registry = IntentRegistry(
        buildVoiceBindings(
          handlers: await ref.watch(voiceHandlersProvider.future),
          undo: await ref.watch(voiceUndoLastCommandProvider.future),
        ),
      );
      registry.assertCovers(await ref.watch(voiceIntentsProvider.future));
      return registry;
    });

/// The one place where what was heard becomes what happens.
final FutureProvider<DecisionPolicy> voiceDecisionPolicyProvider =
    FutureProvider<DecisionPolicy>(
      (Ref ref) async =>
          DecisionPolicy(catalog: await ref.watch(voiceIntentsProvider.future)),
    );

/// Taking back the last write of the session.
///
/// One instance, read by the executor and by the undo banner, so a cancellation
/// spoken and a cancellation clicked cannot behave differently.
final FutureProvider<UndoLastCommand> voiceUndoLastCommandProvider =
    FutureProvider<UndoLastCommand>(
      (Ref ref) async => UndoLastCommand(
        handlers: await ref.watch(voiceHandlersProvider.future),
        dialog: ref.watch(voiceDialogProvider),
        clock: ref.watch(voiceClockProvider),
        ids: ref.watch(voiceCommandIdsProvider),
      ),
    );

/// The only path from a decision to a business use case.
final FutureProvider<ExecuteCommand> voiceExecuteCommandProvider =
    FutureProvider<ExecuteCommand>(
      (Ref ref) async => ExecuteCommand(
        registry: await ref.watch(voiceIntentRegistryProvider.future),
        dialog: ref.watch(voiceDialogProvider),
        clock: ref.watch(voiceClockProvider),
        ids: ref.watch(voiceCommandIdsProvider),
      ),
    );

/// The transcript reader every parser and every reader starts from.
///
/// One instance for the module, so a word dropped as a filler is dropped the same
/// way wherever it is read.
final Provider<TextNormalizer> voiceNormalizerProvider =
    Provider<TextNormalizer>(
      (Ref ref) =>
          TextNormalizer(fillers: ref.watch(voiceConfigProvider).fillers),
    );

/// Spoken names, matched against the catalog.
///
/// Built from the same catalog the mocks write on, archived products included: an
/// archived product must still resolve, so the module can tell the merchant that
/// it is out of his vocabulary rather than report a name it does not know.
final FutureProvider<ProductResolver> voiceProductResolverProvider =
    FutureProvider<ProductResolver>((Ref ref) async {
      final ProductCatalogReader catalog = await ref.watch(
        voiceCatalogReaderProvider.future,
      );
      return ProductResolver(
        products: await catalog.readAllProducts(),
        config: ref.watch(voiceConfigProvider),
        normalizer: ref.watch(voiceNormalizerProvider),
      );
    });

/// The rule parser, which is always available whatever the network does.
final FutureProvider<RuleBasedParser> voiceRuleBasedParserProvider =
    FutureProvider<RuleBasedParser>((Ref ref) async {
      final IntentCatalog intents = await ref.watch(
        voiceIntentsProvider.future,
      );
      final TextNormalizer normalizer = ref.watch(voiceNormalizerProvider);
      return RuleBasedParser(
        normalizer: normalizer,
        detector: IntentDetector(catalog: intents, normalizer: normalizer),
        items: ItemListExtractor(
          resolver: await ref.watch(voiceProductResolverProvider.future),
          lines: LineExtractor(
            numbers: const FrenchNumberParser(),
            config: ref.watch(voiceConfigProvider),
          ),
        ),
        config: ref.watch(voiceConfigProvider),
      );
    });

/// What an answer naming a product designates.
final FutureProvider<SpokenProductResolver> voiceSpokenProductResolverProvider =
    FutureProvider<SpokenProductResolver>(
      (Ref ref) async => ProductNameResolver(
        resolver: await ref.watch(voiceProductResolverProvider.future),
        normalizer: ref.watch(voiceNormalizerProvider),
      ),
    );

/// Completing a line from an answer.
final FutureProvider<AnswerApplication> voiceAnswerApplicationProvider =
    FutureProvider<AnswerApplication>(
      (Ref ref) async => AnswerApplication(
        intents: await ref.watch(voiceIntentsProvider.future),
        resolver: await ref.watch(voiceSpokenProductResolverProvider.future),
      ),
    );

/// Reading an answer the merchant just spoke.
final FutureProvider<AnswerReading> voiceAnswerReadingProvider =
    FutureProvider<AnswerReading>(
      (Ref ref) async => AnswerReading(
        normalizer: ref.watch(voiceNormalizerProvider),
        numbers: const FrenchNumberParser(),
        products: await ref.watch(voiceSpokenProductResolverProvider.future),
      ),
    );

/// Whether the cascading parser attempts the cloud model when online.
final Provider<bool> voiceEnableCloudProvider = Provider<bool>(
  (Ref ref) => kVoiceEnableCloud,
);

/// The Google Gemini API key used for direct Cloud NLU parsing.
final Provider<String> voiceGeminiApiKeyProvider = Provider<String>(
  (Ref ref) => kGeminiApiKey,
);

/// The Rodium AI API key used for Cloud NLU parsing via Rodium AI gateway.
final Provider<String> voiceRodiumApiKeyProvider = Provider<String>(
  (Ref ref) => kRodiumApiKey,
);

/// The model identifier requested from Rodium AI.
final Provider<String> voiceRodiumModelProvider = Provider<String>(
  (Ref ref) => kRodiumModel,
);

/// The base URL for the Rodium AI gateway.
final Provider<String> voiceRodiumBaseUrlProvider = Provider<String>(
  (Ref ref) => kRodiumBaseUrl,
);

/// Real connectivity probe verifying actual Internet reachability.
final Provider<ConnectivityProbe> voiceConnectivityProbeProvider =
    Provider<ConnectivityProbe>((Ref ref) => DataConnectionProbe());

/// Circuit breaker guarding against repeated remote service failures.
final Provider<CircuitBreaker> voiceCircuitBreakerProvider =
    Provider<CircuitBreaker>((Ref ref) {
      return CircuitBreaker(
        clock: ref.watch(voiceClockProvider),
        failureThreshold: 2,
        resetTimeout: const Duration(seconds: 30),
      );
    });

/// Cloud intent parser calling Rodium AI, Google Gemini, or Firebase Cloud Functions.
final FutureProvider<CloudIntentParser>
voiceCloudIntentParserProvider = FutureProvider<CloudIntentParser>((
  Ref ref,
) async {
  final String rodiumApiKey = ref.watch(voiceRodiumApiKeyProvider);
  final String geminiApiKey = ref.watch(voiceGeminiApiKeyProvider);
  final ProductCatalogReader catalogReader = await ref.watch(
    voiceCatalogReaderProvider.future,
  );

  // 1. Explicit Rodium AI key provided
  if (rodiumApiKey.isNotEmpty) {
    final RodiumAiCaller rodiumCaller = RodiumAiCaller(
      apiKey: rodiumApiKey,
      model: ref.watch(voiceRodiumModelProvider),
      baseUrl: ref.watch(voiceRodiumBaseUrlProvider),
    );
    return RemoteCloudIntentParser(
      catalogReader: catalogReader,
      cloudCaller: rodiumCaller.call,
    );
  }

  // 2. GEMINI_API_KEY provided (with auto-detection if user passed an rd_ key)
  if (geminiApiKey.isNotEmpty) {
    if (geminiApiKey.startsWith('rd_')) {
      final RodiumAiCaller rodiumCaller = RodiumAiCaller(
        apiKey: geminiApiKey,
        model: ref.watch(voiceRodiumModelProvider),
        baseUrl: ref.watch(voiceRodiumBaseUrlProvider),
      );
      return RemoteCloudIntentParser(
        catalogReader: catalogReader,
        cloudCaller: rodiumCaller.call,
      );
    }

    final DirectGeminiCaller geminiCaller = DirectGeminiCaller(
      apiKey: geminiApiKey,
      systemPrompt: ref.watch(kioskRegistryProvider).buildSystemPrompt(),
    );
    return RemoteCloudIntentParser(
      catalogReader: catalogReader,
      cloudCaller: geminiCaller.call,
    );
  }

  // 3. Fallback to Firebase Cloud Functions default
  return RemoteCloudIntentParser(catalogReader: catalogReader);
});

/// The parser used by the turn executor.
///
/// When [voiceEnableCloudProvider] is true, uses [CascadingParser] combining
/// the cloud model and the local rule parser under a strict time budget.
/// When false, delegates directly to [voiceRuleBasedParserProvider].
final FutureProvider<IntentParser> voiceParserProvider =
    FutureProvider<IntentParser>((Ref ref) async {
      final RuleBasedParser local = await ref.watch(
        voiceRuleBasedParserProvider.future,
      );
      if (!ref.watch(voiceEnableCloudProvider)) {
        return local;
      }
      return CascadingParser(
        local: local,
        cloud: await ref.watch(voiceCloudIntentParserProvider.future),
        connectivity: ref.watch(voiceConnectivityProbeProvider),
        circuitBreaker: ref.watch(voiceCircuitBreakerProvider),
        timeBudget: const Duration(milliseconds: 2000),
      );
    });

/// One utterance in, what happens out.
final FutureProvider<HandleUtterance> voiceHandleUtteranceProvider =
    FutureProvider<HandleUtterance>(
      (Ref ref) async => HandleUtterance(
        parser: await ref.watch(voiceParserProvider.future),
        validator: await ref.watch(voiceCommandValidatorProvider.future),
        policy: await ref.watch(voiceDecisionPolicyProvider.future),
        executor: await ref.watch(voiceExecuteCommandProvider.future),
        dialog: ref.watch(voiceDialogProvider),
        answers: await ref.watch(voiceAnswerApplicationProvider.future),
        reading: await ref.watch(voiceAnswerReadingProvider.future),
      ),
    );

/// How the two device services behave on this phone.
///
/// A plain provider with no async work, so a test replaces the whole technical
/// configuration of the microphone and the voice in one override.
final Provider<VoiceServiceSettings> voiceServiceSettingsProvider =
    Provider<VoiceServiceSettings>((Ref ref) => const VoiceServiceSettings());

/// The microphone of the device.
///
/// The only adapter in the module that names a plugin, and it names it through
/// [PluginDeviceSpeechRecognizer] rather than directly: the port the session uses
/// is the one that can be faked, and the engine is a parameter so the adapter's
/// own rules - which language, what the shop's vocabulary is, what a refused
/// permission means - are reachable from a test without a phone.
final FutureProvider<SpeechRecognizerPort> voiceRecognizerProvider =
    FutureProvider<SpeechRecognizerPort>((Ref ref) async {
      return PlatformSpeechRecognizer(
        device: PluginDeviceSpeechRecognizer(),
        settings: ref.watch(voiceServiceSettingsProvider),
        vocabulary: await _shopVocabulary(ref),
      );
    });

/// The voice of the device.
final Provider<TtsPort> voiceTtsProvider = Provider<TtsPort>(
  (Ref ref) => PlatformTts(
    device: PluginDeviceSpeechSpeaker(),
    settings: ref.watch(voiceServiceSettingsProvider),
  ),
);

/// The words the recogniser is biased toward, taken from the same catalog the
/// router reads.
///
/// Sorted so the payload does not change with the order the shop happens to have
/// stored its products in, and capped by the settings, because the engines that
/// accept a vocabulary ignore a long one and the ones that do not are slow with
/// it.
Future<List<String>> _shopVocabulary(Ref ref) async {
  final ProductCatalogReader catalog = await ref.watch(
    voiceCatalogReaderProvider.future,
  );
  final List<ProductSnapshot> products = await catalog.readActiveProducts();
  final Set<String> words = <String>{};
  for (final ProductSnapshot product in products) {
    words.add(product.name.toLowerCase());
    words.addAll(product.aliases);
  }
  final List<String> sorted = words.toList()..sort();
  return sorted
      .take(ref.watch(voiceServiceSettingsProvider).vocabularyLimit)
      .toList();
}

/// The natural response formulator (Cascading Cloud AI & Offline Natural).
final Provider<MessageFormulator>
voiceMessageFormulatorProvider = Provider<MessageFormulator>((Ref ref) {
  final ConnectivityProbe connectivity = ref.watch(
    voiceConnectivityProbeProvider,
  );
  final CircuitBreaker circuitBreaker = ref.watch(voiceCircuitBreakerProvider);
  final String rodiumApiKey = ref.watch(voiceRodiumApiKeyProvider);
  final String geminiApiKey = ref.watch(voiceGeminiApiKeyProvider);

  final MessageFormulator aiFormulator;
  if (rodiumApiKey.isNotEmpty) {
    aiFormulator = AiMessageFormulator(
      apiKey: rodiumApiKey,
      endpointUrl: '${ref.watch(voiceRodiumBaseUrlProvider)}/chat/completions',
    );
  } else if (geminiApiKey.isNotEmpty) {
    if (geminiApiKey.startsWith('rd_')) {
      aiFormulator = AiMessageFormulator(
        apiKey: geminiApiKey,
        endpointUrl:
            '${ref.watch(voiceRodiumBaseUrlProvider)}/chat/completions',
      );
    } else {
      aiFormulator = AiMessageFormulator(apiKey: geminiApiKey);
    }
  } else {
    aiFormulator = const OfflineNaturalFormulator();
  }

  return CascadingMessageFormulator(
    aiFormulator: aiFormulator,
    connectivity: connectivity,
    circuitBreaker: circuitBreaker,
  );
});

/// Extensible tool registry for the KioskMind assistant.
final Provider<KioskRegistry> kioskRegistryProvider = Provider<KioskRegistry>((
  Ref ref,
) {
  final KioskRegistry registry = KioskRegistry();

  // Default core kiosk tools
  registry.register(
    KioskToolSpec(
      name: 'record_sale',
      label: 'Enregistrer une vente',
      example: 'vends deux savons',
      paramLabels: const <String, String>{
        'items':
            'Liste des articles avec productId, qty et spokenUnitPrice optionnel',
      },
      jsonFormatExample:
          '{"intentId": "record_sale", "items": [{"productId": "<id_catalogue>", "qty": 2.0, "spokenUnitPrice": 500}]}',
      declarationKeywords: const <String>{'vends', 'vente', 'acheter', 'prend'},
      handler: (params) async =>
          const FactResult(operation: 'record_sale', data: {}),
    ),
  );
  registry.register(
    KioskToolSpec(
      name: 'record_restock',
      label: 'Réapprovisionnement du stock',
      example: 'ajoute 10 sacs de riz',
      paramLabels: const <String, String>{
        'items':
            'Liste des articles avec productId, qty et spokenUnitCost optionnel',
      },
      jsonFormatExample:
          '{"intentId": "record_restock", "items": [{"productId": "<id_catalogue>", "qty": 5.0, "spokenUnitCost": 400}]}',
      declarationKeywords: const <String>{
        'ajoute',
        'entree',
        'recu',
        'stocker',
        'reappro',
        'reassort',
        'achat',
        'livraison',
        'restock',
      },
      handler: (params) async =>
          const FactResult(operation: 'record_restock', data: {}),
    ),
  );
  registry.register(
    KioskToolSpec(
      name: 'query_stock',
      label: 'Consulter le stock',
      example: 'combien de sucre en stock',
      paramLabels: const <String, String>{
        'productId': 'Identifiant du produit dans le catalogue',
      },
      jsonFormatExample:
          '{"intentId": "query_stock", "productId": "<id_catalogue>"}',
      declarationKeywords: const <String>{'stock', 'combien', 'reste'},
      handler: (params) async =>
          const FactResult(operation: 'query_stock', data: {}),
    ),
  );
  registry.register(
    KioskToolSpec(
      name: 'cancel_last_sale',
      label: 'Annuler la dernière vente',
      example: 'annule la vente',
      jsonFormatExample: '{"intentId": "cancel_last_sale"}',
      declarationKeywords: const <String>{'annuler', 'annule', 'retour'},
      handler: (params) async =>
          const FactResult(operation: 'cancel_last_sale', data: {}),
    ),
  );

  return registry;
});
