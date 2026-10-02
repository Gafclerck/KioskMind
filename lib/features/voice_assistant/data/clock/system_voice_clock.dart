import '../../domain/ports/voice_clock.dart';

/// The device clock, which is the only clock the module ever reads.
///
/// The window that lets a sale be undone and the timeout that ends a question are
/// both real time: a merchant who says nothing is not waiting inside a simulated
/// hour. Everything that must not depend on real time takes a [VoiceClock] instead,
/// and never this class.
final class SystemVoiceClock implements VoiceClock {
  const SystemVoiceClock();

  @override
  DateTime now() => DateTime.now();
}
