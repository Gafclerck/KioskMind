import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/clock/system_voice_clock.dart';
import 'package:kiosk_mind/features/voice_assistant/data/commands/session_command_ids.dart';

import 'fake_clock.dart';

/// The two adapters that turn the injected ports into something the app can run.
///
/// They are the boundary between "no time of its own" and "reads the device", so
/// what is worth pinning down is narrow: the clock is real time, and the identifiers
/// are unique, ordered and readable.
void main() {
  group('SystemVoiceClock', () {
    test('reads the device clock, and moves', () async {
      const SystemVoiceClock clock = SystemVoiceClock();

      final DateTime first = clock.now();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(clock.now().isBefore(first), isFalse);
    });
  });

  group('SessionCommandIds', () {
    late FakeClock clock;
    late SessionCommandIds ids;

    setUp(() {
      clock = FakeClock(DateTime(2026, 3, 14, 8, 30));
      ids = SessionCommandIds(clock: clock);
    });

    test('an identifier says it came from voice', () {
      expect(ids.next(), startsWith('${SessionCommandIds.prefix}-'));
    });

    test('two identifiers issued in the same millisecond differ', () {
      final String first = ids.next();
      final String second = ids.next();

      expect(first, isNot(second));
    });

    test('an identifier never repeats', () {
      final List<String> issued = <String>[
        for (int index = 0; index < 50; index++) ids.next(),
      ];

      expect(issued.toSet(), hasLength(50));
    });

    test('two sessions apart in time never collide', () {
      final String first = ids.next();
      clock.elapse(const Duration(seconds: 1));

      expect(SessionCommandIds(clock: clock).next(), isNot(first));
    });

    test('the instant is readable, so a written command can be traced', () {
      final String issued = ids.next();

      expect(issued, contains('${clock.now().millisecondsSinceEpoch}'));
    });
  });
}
