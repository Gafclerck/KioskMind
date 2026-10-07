/// Build-time switch of the voice composition root.
///
/// Defaults to the real handlers. Mocks were the default while `sales` and
/// `products_stock` had no use case to call, which is no longer the case, and a
/// default that keeps answering from a fixture makes a working assistant look
/// broken: every command the rules can hear succeeds against sample products the
/// merchant has never stocked, and the ones that need the model never arrive.
///
/// Opt back in with `--dart-define=VOICE_USE_MOCKS=true` to demo the voice without a
/// catalogue, or override `voiceUseMocksProvider` per test.
const bool kVoiceUseMocks = bool.fromEnvironment(
  'VOICE_USE_MOCKS',
  defaultValue: false,
);

/// Whether the cascading parser attempts the cloud language model when online.
///
/// Off by default too, and for the same reason a missing key is worth naming rather
/// than hiding: turning the cloud on is a deployment decision, and it only means
/// something once a key is present. With the cloud off or the key absent,
/// `voiceParserProvider` builds a `LocalOnlyParser` that records which of the two it
/// was. Silently answering from the rules is the one outcome nobody could diagnose.
const bool kVoiceEnableCloud = bool.fromEnvironment(
  'VOICE_ENABLE_CLOUD',
  defaultValue: true,
);

/// The Google Gemini API key used for direct Cloud NLU parsing when provided.
///
/// Can be set at build or run time with `--dart-define=GEMINI_API_KEY=AIzaSy...`.
const String kGeminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);

/// The Rodium AI API key used for Cloud NLU parsing via Rodium AI gateway.
///
/// Can be set at build or run time with `--dart-define=RODIUM_API_KEY=rd_sk_...`.
const String kRodiumApiKey = String.fromEnvironment(
  'RODIUM_API_KEY',
  defaultValue: '',
);

/// Optional model identifier for Rodium AI (defaults to 'google/gemini-2.5-flash').
const String kRodiumModel = String.fromEnvironment(
  'RODIUM_MODEL',
  defaultValue: 'google/gemini-2.5-flash',
);

/// Optional base URL for Rodium AI gateway (defaults to 'https://api.rodiumai.io/v1').
const String kRodiumBaseUrl = String.fromEnvironment(
  'RODIUM_BASE_URL',
  defaultValue: 'https://api.rodiumai.io/v1',
);
