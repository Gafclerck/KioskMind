import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/cloud_intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/cascading_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/circuit_breaker.dart';

import 'fake_clock.dart';

void main() {
  late FakeClock clock;
  late CircuitBreaker breaker;
  late _FakeCloudParser cloud;
  late _FakeLocalParser local;
  late CascadingParser cascading;

  const CommandProposal cloudProposal = CommandProposal(
    intentId: 'record_sale',
    slots: <Slot>[],
    doubts: <Doubt>[],
    origin: ProposalOrigin.languageModel,
  );

  const CommandProposal localProposal = CommandProposal.rules(
    intentId: 'record_sale',
    slots: <Slot>[],
  );

  setUp(() {
    clock = FakeClock(DateTime(2026, 10, 3, 12, 0));
    breaker = CircuitBreaker(
      clock: clock,
      failureThreshold: 2,
      resetTimeout: const Duration(seconds: 15),
    );
    cloud = _FakeCloudParser(result: cloudProposal);
    local = _FakeLocalParser(result: localProposal);
    cascading = CascadingParser(
      local: local,
      cloud: cloud,
      circuitBreaker: breaker,
      timeBudget: const Duration(milliseconds: 100),
    );
  });

  test('when circuit closed, uses cloud proposal', () async {
    final CommandProposal proposal = await cascading.parse('vendu deux sucres');

    expect(proposal.origin, ProposalOrigin.languageModel);
    expect(cloud.callCount, 1);
    expect(local.callCount, 0);
    expect(breaker.state, CircuitState.closed);
  });

  test(
    'when circuit breaker is open, skips cloud parser and uses local parser',
    () async {
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.canAttempt(), isFalse);

      final CommandProposal proposal = await cascading.parse(
        'vendu deux sucres',
      );

      expect(proposal.origin, ProposalOrigin.rules);
      expect(cloud.callCount, 0);
      expect(local.callCount, 1);
    },
  );

  test(
    'when cloud parser returns null, falls back to local parser and records failure',
    () async {
      cloud.result = null;

      final CommandProposal proposal = await cascading.parse(
        'vendu deux sucres',
      );

      expect(proposal.origin, ProposalOrigin.rules);
      expect(cloud.callCount, 1);
      expect(local.callCount, 1);
      expect(breaker.consecutiveFailures, 1);
    },
  );

  test(
    'when cloud parser throws, falls back to local parser and records failure',
    () async {
      cloud.error = Exception('Network reset');

      final CommandProposal proposal = await cascading.parse(
        'vendu deux sucres',
      );

      expect(proposal.origin, ProposalOrigin.rules);
      expect(cloud.callCount, 1);
      expect(local.callCount, 1);
      expect(breaker.consecutiveFailures, 1);
    },
  );

  test(
    'when cloud parser exceeds time budget, falls back to local parser',
    () async {
      cloud.delay = const Duration(milliseconds: 250);

      final CommandProposal proposal = await cascading.parse(
        'vendu deux sucres',
      );

      expect(proposal.origin, ProposalOrigin.rules);
      expect(cloud.callCount, 1);
      expect(local.callCount, 1);
      expect(breaker.consecutiveFailures, 1);
    },
  );

  test(
    'repeated failures trip the circuit breaker and allow subsequent fast local fallback',
    () async {
      cloud.error = Exception('500 Internal Error');

      await cascading.parse('phrase 1');
      expect(breaker.consecutiveFailures, 1);
      expect(breaker.state, CircuitState.closed);

      await cascading.parse('phrase 2');
      expect(breaker.consecutiveFailures, 2);
      expect(breaker.state, CircuitState.open);

      // Third call: fast fallback, cloud is not even contacted
      final CommandProposal proposal = await cascading.parse('phrase 3');
      expect(proposal.origin, ProposalOrigin.rules);
      expect(cloud.callCount, 2);
    },
  );
}

final class _FakeCloudParser implements CloudIntentParser {
  _FakeCloudParser({this.result});

  CommandProposal? result;
  Duration? delay;
  Exception? error;
  int callCount = 0;

  @override
  Future<CommandProposal?> parse(String raw) async {
    callCount += 1;
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

final class _FakeLocalParser implements IntentParser {
  _FakeLocalParser({required this.result});

  final CommandProposal result;
  int callCount = 0;

  @override
  CommandProposal parse(String raw) {
    callCount += 1;
    return result;
  }
}
