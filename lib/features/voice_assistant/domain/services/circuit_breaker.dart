import '../ports/voice_clock.dart';

/// The health state of the remote interpretation circuit.
enum CircuitState {
  /// Calls to the cloud parser are permitted.
  closed,

  /// Calls to the cloud parser are blocked due to repeated failures.
  open,

  /// A test call is permitted to verify if the cloud parser has recovered.
  halfOpen,
}

/// Protects against repeatedly calling a failing cloud service.
///
/// When the cloud parser fails [failureThreshold] times in a row, the circuit
/// opens and subsequent calls fall back immediately to local parsing without
/// waiting for a network timeout. After [resetTimeout], the circuit becomes
/// half-open to allow a single probe attempt.
final class CircuitBreaker {
  CircuitBreaker({
    required this.clock,
    this.failureThreshold = 3,
    this.resetTimeout = const Duration(seconds: 30),
  });

  final VoiceClock clock;
  final int failureThreshold;
  final Duration resetTimeout;

  CircuitState _state = CircuitState.closed;
  int _consecutiveFailures = 0;
  DateTime? _openedAt;

  /// Current state of the circuit.
  CircuitState get state => _state;

  /// Number of consecutive failures recorded since last success.
  int get consecutiveFailures => _consecutiveFailures;

  /// Whether a remote call should be attempted right now.
  bool canAttempt() {
    if (_state == CircuitState.closed) {
      return true;
    }
    if (_state == CircuitState.halfOpen) {
      return true;
    }
    final DateTime openedAt = _openedAt!;
    if (clock.now().difference(openedAt) >= resetTimeout) {
      _state = CircuitState.halfOpen;
      return true;
    }
    return false;
  }

  /// Records a successful remote call, closing the circuit.
  void recordSuccess() {
    _consecutiveFailures = 0;
    _state = CircuitState.closed;
    _openedAt = null;
  }

  /// Records a remote failure or timeout, tripping the circuit when needed.
  void recordFailure() {
    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.open;
      _openedAt = clock.now();
      return;
    }
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= failureThreshold) {
      _state = CircuitState.open;
      _openedAt = clock.now();
    }
  }
}
