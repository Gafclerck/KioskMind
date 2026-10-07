import 'package:kiosk_mind/features/voice_assistant/domain/ports/voice_clock.dart';

/// A clock the test moves by hand.
///
/// The undo window, the question timeout and the session expiry are all real time
/// in the app, so a test that waited for them would be slow and flaky. It moves this
/// one instead, which also makes the boundary cases reachable: a test can sit exactly
/// on the last millisecond of a window and know which side of it it is on.
class FakeClock implements VoiceClock {
  FakeClock(this._instant);

  DateTime _instant;

  /// The time the module will read next.
  void set(DateTime instant) => _instant = instant;

  /// Time passes without the test waiting for it.
  void elapse(Duration by) => _instant = _instant.add(by);

  @override
  DateTime now() => _instant;
}
