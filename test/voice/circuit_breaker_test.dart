import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/circuit_breaker.dart';

import 'fake_clock.dart';

void main() {
  late FakeClock clock;
  late CircuitBreaker breaker;

  setUp(() {
    clock = FakeClock(DateTime(2026, 10, 3, 10, 0));
    breaker = CircuitBreaker(
      clock: clock,
      failureThreshold: 3,
      resetTimeout: const Duration(seconds: 30),
    );
  });

  test('starts closed with zero failures and allows attempt', () {
    expect(breaker.state, CircuitState.closed);
    expect(breaker.consecutiveFailures, 0);
    expect(breaker.canAttempt(), isTrue);
  });

  test('remains closed when failures stay below threshold', () {
    breaker.recordFailure();
    breaker.recordFailure();

    expect(breaker.state, CircuitState.closed);
    expect(breaker.consecutiveFailures, 2);
    expect(breaker.canAttempt(), isTrue);
  });

  test(
    'opens after reaching consecutive failure threshold and blocks attempt',
    () {
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();

      expect(breaker.state, CircuitState.open);
      expect(breaker.consecutiveFailures, 3);
      expect(breaker.canAttempt(), isFalse);
    },
  );

  test('transitions from open to half-open after reset timeout elapses', () {
    breaker.recordFailure();
    breaker.recordFailure();
    breaker.recordFailure();
    expect(breaker.canAttempt(), isFalse);

    // 29 seconds: still open
    clock.elapse(const Duration(seconds: 29));
    expect(breaker.canAttempt(), isFalse);
    expect(breaker.state, CircuitState.open);

    // 30 seconds: transitions to half-open and allows one test attempt
    clock.elapse(const Duration(seconds: 1));
    expect(breaker.canAttempt(), isTrue);
    expect(breaker.state, CircuitState.halfOpen);
  });

  test(
    'success in half-open state resets circuit to closed with zero failures',
    () {
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();

      clock.elapse(const Duration(seconds: 30));
      expect(breaker.canAttempt(), isTrue);
      expect(breaker.state, CircuitState.halfOpen);

      breaker.recordSuccess();
      expect(breaker.state, CircuitState.closed);
      expect(breaker.consecutiveFailures, 0);
      expect(breaker.canAttempt(), isTrue);
    },
  );

  test('failure in half-open state re-opens circuit immediately', () {
    breaker.recordFailure();
    breaker.recordFailure();
    breaker.recordFailure();

    clock.elapse(const Duration(seconds: 30));
    expect(breaker.canAttempt(), isTrue);
    expect(breaker.state, CircuitState.halfOpen);

    breaker.recordFailure();
    expect(breaker.state, CircuitState.open);
    expect(breaker.canAttempt(), isFalse);

    // Needs another full reset timeout
    clock.elapse(const Duration(seconds: 29));
    expect(breaker.canAttempt(), isFalse);

    clock.elapse(const Duration(seconds: 1));
    expect(breaker.canAttempt(), isTrue);
    expect(breaker.state, CircuitState.halfOpen);
  });

  test('success in closed state resets previous failure count', () {
    breaker.recordFailure();
    breaker.recordFailure();
    expect(breaker.consecutiveFailures, 2);

    breaker.recordSuccess();
    expect(breaker.consecutiveFailures, 0);
    expect(breaker.state, CircuitState.closed);
  });
}
