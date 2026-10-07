import 'dart:io';

import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_fixture_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/item_list_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/line_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rule_based_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/intent_detector.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/text_normalizer.dart';

/// The rule parser (T1), wired exactly the way the composition root wires it.
///
/// The tests share one wiring so that what they exercise is the pipeline the app
/// runs, not a hand-built variant of it. Only the tunables vary, because a test
/// that needs a different threshold must say which one it depends on.
class RuleParserHarness {
  RuleParserHarness({this.config = const VoiceConfig()})
    : normalizer = TextNormalizer(fillers: config.fillers) {
    final IntentCatalog catalog = parseIntentCatalog(
      File(intentCatalogAsset).readAsStringSync(),
    );
    intents = catalog;
    detector = IntentDetector(catalog: catalog, normalizer: normalizer);
    resolver = ProductResolver(
      products: parseCatalogFixture(
        File(catalogFixtureAsset).readAsStringSync(),
      ),
      config: config,
      normalizer: normalizer,
    );
    lines = LineExtractor(numbers: const FrenchNumberParser(), config: config);
    parser = RuleBasedParser(
      normalizer: normalizer,
      detector: detector,
      items: ItemListExtractor(resolver: resolver, lines: lines),
      config: config,
    );
  }

  final VoiceConfig config;
  final TextNormalizer normalizer;

  /// The catalog the parser was built from, for the services that read the intent
  /// definitions the same way the parser does.
  late final IntentCatalog intents;

  late final IntentDetector detector;
  late final ProductResolver resolver;
  late final LineExtractor lines;
  late final RuleBasedParser parser;

  /// The tokens of [raw], as the parser sees them.
  List<String> tokensOf(String raw) => normalizer.normalize(raw).tokens;
}

/// Path of the catalog fixture, declared as an asset.
const String catalogFixtureAsset = 'voice/golden/catalog_fixture.json';

/// Products of the shipped fixture, for tests that only need the catalog.
List<ProductSnapshot> fixtureProducts() {
  return parseCatalogFixture(File(catalogFixtureAsset).readAsStringSync());
}
