/// Generates the identifier of a voice command.
///
/// Injected rather than taken from a uuid package so the module keeps no
/// randomness of its own: a test names its own identifiers, and a replay of the
/// same utterance can be made to reuse one on purpose (contract A3).
abstract interface class CommandIdFactory {
  /// An identifier not yet used in this session.
  String next();
}
