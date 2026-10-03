/// Build-time switch of the voice composition root.
///
/// Mocks are the default so the demo runs before `sales` and `products_stock`
/// deliver their use cases. Once a real handler exists for an intent, build
/// with `--dart-define=VOICE_USE_MOCKS=false` and override per provider in
/// tests.
const bool kVoiceUseMocks = bool.fromEnvironment(
  'VOICE_USE_MOCKS',
  defaultValue: true,
);

/// Whether the cascading parser attempts the cloud language model when online.
///
/// Can be disabled with `--dart-define=VOICE_ENABLE_CLOUD=false` or overridden
/// per provider in tests.
const bool kVoiceEnableCloud = bool.fromEnvironment(
  'VOICE_ENABLE_CLOUD',
  defaultValue: false,
);
