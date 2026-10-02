import '../../domain/ports/command_id_factory.dart';
import '../../domain/ports/voice_clock.dart';

/// Command identifiers of one session, readable and unique without a dependency.
///
/// The identifier of a command is the identifier of the document it writes
/// (contract C7), so a replay of the same utterance must not write twice. Two
/// commands can fall on the same millisecond, hence the counter: uniqueness in the
/// session comes from the counter and readability from the instant, so a written
/// command can be traced back to when the merchant spoke it.
///
/// No uuid package is needed for this, and none is added for it: the module keeps
/// no randomness, and the few digits an operator reads are worth more than the
/// 128 bits nobody reads.
final class SessionCommandIds implements CommandIdFactory {
  SessionCommandIds({required this.clock});

  /// Prefix of every identifier, so a document written by voice is recognisable
  /// as such from its id alone.
  static const String prefix = 'voice';

  final VoiceClock clock;
  int _issued = 0;

  @override
  String next() {
    _issued += 1;
    return '$prefix-${clock.now().millisecondsSinceEpoch}-$_issued';
  }
}
