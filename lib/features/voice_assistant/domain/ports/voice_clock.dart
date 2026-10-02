/// The time the voice module reads.
///
/// Injected rather than taken from `DateTime.now()` so the undo window, the
/// question timeout and the session expiry are testable without waiting, and so a
/// replay produces the same result at any hour. The device clock is what the
/// command context carries too (contract C7), so this port is the only source of
/// time in the module.
abstract interface class VoiceClock {
  /// Device time at the moment of the call.
  DateTime now();
}
