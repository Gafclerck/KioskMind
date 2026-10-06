import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/diagnostics/in_memory_parse_outcome_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/diagnostics/logging_parse_outcome_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/cloud_call_failure.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/remote_cloud_intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rodium_ai_caller.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/parse_route.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/cloud_intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/connectivity_probe.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/cascading_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/circuit_breaker.dart';

import 'fake_clock.dart';

/// A route is a fact about one utterance, and every way of failing to understand it
/// used to reach the merchant as the same sentence. These tests pin each reason to the
/// layer that knows it, because a journal that guesses is worse than no journal: it
/// would send whoever reads it looking in the wrong place.

ProductSnapshot _product(String id, {required String name}) {
  return ProductSnapshot(
    id: id,
    name: name,
    aliases: const <String>[],
    unit: 'PIECE',
    price: 500,
    purchasePrice: 400,
    stock: 10,
    alertThreshold: 2,
    averageDailyQty: 1,
    isArchived: false,
  );
}

final class _Connectivity implements ConnectivityProbe {
  _Connectivity(this.online);

  bool online;

  @override
  Future<bool> get isOnline async => online;
}

final class _Cloud implements CloudIntentParser {
  _Cloud({this.result});

  CommandProposal? result;
  Object? error;
  Duration? delay;

  @override
  Future<CommandProposal?> parse(String raw) async {
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

final class _Local implements IntentParser {
  int callCount = 0;

  @override
  CommandProposal parse(String raw) {
    callCount += 1;
    return CommandProposal.rules(intentId: 'record_sale', slots: <Slot>[]);
  }
}

void main() {
  group('le journal retient ce qui a été compris', () {
    test('garde le plus récent en premier', () {
      final InMemoryParseOutcomeJournal journal = InMemoryParseOutcomeJournal();

      journal.record(
        ParseRouteEvent(
          utterance: 'premiere',
          reason: ParseRouteReason.offline,
        ),
      );
      journal.record(
        ParseRouteEvent(
          utterance: 'seconde',
          reason: ParseRouteReason.cloudAnswered,
        ),
      );

      expect(journal.events.first.utterance, equals('seconde'));
      expect(journal.events.last.utterance, equals('premiere'));
    });

    test('ne grossit pas sans borne', () {
      final InMemoryParseOutcomeJournal journal = InMemoryParseOutcomeJournal(
        capacity: 3,
      );

      for (int i = 0; i < 10; i++) {
        journal.record(
          ParseRouteEvent(
            utterance: 'phrase $i',
            reason: ParseRouteReason.offline,
          ),
        );
      }

      expect(journal.events, hasLength(3));
      expect(journal.events.first.utterance, equals('phrase 9'));
      expect(journal.events.last.utterance, equals('phrase 7'));
    });

    test('la lecture ne donne pas la main courante', () {
      final InMemoryParseOutcomeJournal journal = InMemoryParseOutcomeJournal();
      journal.record(
        ParseRouteEvent(utterance: 'phrase', reason: ParseRouteReason.offline),
      );

      expect(() => journal.events.clear(), throwsUnsupportedError);
    });

    test('ne casse jamais la lecture quand on enregistre', () {
      final InMemoryParseOutcomeJournal journal = InMemoryParseOutcomeJournal();

      expect(
        () => journal.record(
          ParseRouteEvent(utterance: 'x', reason: ParseRouteReason.offline),
        ),
        returnsNormally,
      );
      expect(journal.clear, returnsNormally);
      expect(journal.events, isEmpty);
    });

    test('distingue un succes d une panne', () {
      const ParseRouteEvent answered = ParseRouteEvent(
        utterance: 'phrase',
        reason: ParseRouteReason.cloudAnswered,
      );
      const ParseRouteEvent failed = ParseRouteEvent(
        utterance: 'phrase',
        reason: ParseRouteReason.timeout,
      );

      expect(answered.fromCloud, isTrue);
      expect(answered.isFailure, isFalse);
      expect(failed.fromCloud, isFalse);
      expect(failed.isFailure, isTrue);
    });

    test('le decorateur journalise les memes evenements', () {
      final InMemoryParseOutcomeJournal inner = InMemoryParseOutcomeJournal();
      final LoggingParseOutcomeJournal journal = LoggingParseOutcomeJournal(
        inner,
      );

      journal.record(
        ParseRouteEvent(
          utterance: 'phrase',
          reason: ParseRouteReason.circuitOpen,
        ),
      );

      expect(journal.events, hasLength(1));
      expect(inner.events, hasLength(1));
      expect(journal.events.first.reason, ParseRouteReason.circuitOpen);
    });
  });

  group('la cascade dit quel chemin elle a pris', () {
    late InMemoryParseOutcomeJournal journal;
    late FakeClock clock;
    late CircuitBreaker breaker;
    late _Connectivity connectivity;
    late _Cloud cloud;
    late _Local local;
    late CascadingParser cascading;

    const CommandProposal answered = CommandProposal(
      intentId: 'query_stock',
      slots: <Slot>[],
      doubts: <Doubt>[],
      origin: ProposalOrigin.languageModel,
    );

    setUp(() {
      journal = InMemoryParseOutcomeJournal();
      clock = FakeClock(DateTime(2026, 10, 5, 9));
      breaker = CircuitBreaker(
        clock: clock,
        failureThreshold: 2,
        resetTimeout: const Duration(seconds: 30),
      );
      connectivity = _Connectivity(true);
      cloud = _Cloud(result: answered);
      local = _Local();
      cascading = CascadingParser(
        local: local,
        cloud: cloud,
        connectivity: connectivity,
        circuitBreaker: breaker,
        journal: journal,
        timeBudget: const Duration(milliseconds: 60),
      );
    });

    test('note quand le cloud a repondu', () async {
      await cascading.parse('combien de sucre reste-t-il');

      expect(journal.events, hasLength(1));
      expect(journal.events.first.reason, ParseRouteReason.cloudAnswered);
      expect(
        journal.events.first.utterance,
        equals('combien de sucre reste-t-il'),
      );
    });

    test('note hors ligne et ne contacte pas le cloud', () async {
      connectivity.online = false;

      await cascading.parse('combien de sucre reste-t-il');

      expect(journal.events.single.reason, ParseRouteReason.offline);
      expect(local.callCount, 1);
    });

    test('note le circuit ouvert et ne contacte pas le cloud', () async {
      breaker.recordFailure();
      breaker.recordFailure();

      await cascading.parse('combien de sucre reste-t-il');

      expect(journal.events.single.reason, ParseRouteReason.circuitOpen);
    });

    test('note le depassement de budget avec la valeur du budget', () async {
      cloud
        ..result = null
        ..delay = const Duration(milliseconds: 200);

      await cascading.parse('combien de sucre reste-t-il');

      final ParseRouteEvent event = journal.events.first;
      expect(event.reason, ParseRouteReason.timeout);
      expect(event.detail, contains('60'));
    });

    test('note une panne en gardant le detail', () async {
      cloud
        ..result = null
        ..error = const CloudCallFailure('Rodium AI HTTP 401: cle refusee');

      await cascading.parse('combien de sucre reste-t-il');

      final ParseRouteEvent event = journal.events.first;
      expect(event.reason, ParseRouteReason.unreachable);
      expect(event.detail, contains('401'));
      expect(event.detail, contains('cle refusee'));
    });

    test('laisse le parseur distant etre le seul a parler dun null', () async {
      cloud.result = null;

      await cascading.parse('phrase incomprise');

      // Une reponse inutilisable est la nouvelle du parseur distant, qui l'a deja
      // ecrite avec sa raison. La cascade n'ajoute pas de ligne: deux lignes pour une
      // panne remettraient la raison grossiere au-dessus de la precise, l'historique
      // se lisant du plus recent au plus ancien.
      expect(journal.events, isEmpty);
      expect(local.callCount, 1);
    });

    test('fonctionne sans journal', () async {
      final CascadingParser sansJournal = CascadingParser(
        local: local,
        cloud: cloud,
        connectivity: connectivity,
        circuitBreaker: breaker,
        timeBudget: const Duration(milliseconds: 60),
      );

      expect(
        () => sansJournal.parse('combien de sucre reste-t-il'),
        returnsNormally,
      );
    });
  });

  group('le parseur distant dit pourquoi sa reponse ne servait a rien', () {
    late InMemoryParseOutcomeJournal journal;
    late InMemoryProductCatalog catalog;
    late RemoteCloudIntentParser parser;

    setUp(() {
      journal = InMemoryParseOutcomeJournal();
      catalog = InMemoryProductCatalog(<ProductSnapshot>[
        _product('p_sucre', name: 'Sucre'),
      ]);
      parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        journal: journal,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{},
      );
    });

    test('note une reponse sans intention', () async {
      expect(await parser.parse('bonjour'), isNull);

      final ParseRouteEvent event = journal.events.single;
      expect(event.reason, ParseRouteReason.noIntentReturned);
      expect(event.utterance, equals('bonjour'));
    });

    test('note une intention vide comme une reponse sans intention', () async {
      parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        journal: journal,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': '',
        },
      );

      expect(await parser.parse('bonjour'), isNull);
      expect(journal.events.single.reason, ParseRouteReason.noIntentReturned);
    });

    test('note une intention inconnue en gardant son nom', () async {
      parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        journal: journal,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'record_client_debt',
        },
      );

      expect(await parser.parse('amadou me doit cinq mille'), isNull);

      final ParseRouteEvent event = journal.events.single;
      expect(event.reason, ParseRouteReason.unsupportedIntent);
      expect(event.detail, equals('record_client_debt'));
    });

    test('note un appel casse avec le code HTTP', () async {
      parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        journal: journal,
        cloudCaller: (functionName, parameters) async =>
            throw const CloudCallFailure('Rodium AI HTTP 429: quota epuise'),
      );

      expect(await parser.parse('combien de sucre reste-t-il'), isNull);

      final ParseRouteEvent event = journal.events.single;
      expect(event.reason, ParseRouteReason.unreachable);
      expect(event.detail, contains('429'));
    });

    test('ne note rien quand la reponse est utilisee', () async {
      parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        journal: journal,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'query_stock',
          'productId': 'p_sucre',
        },
      );

      expect(await parser.parse('combien de sucre reste-t-il'), isNotNull);
      expect(journal.events, isEmpty);
    });

    test(
      'distingue une reponse illisible d une passerelle injoignable',
      () async {
        // La passerelle a repondu: c'est sa reponse qui est illisible, pas elle.
        parser = RemoteCloudIntentParser(
          catalogReader: catalog,
          journal: journal,
          cloudCaller: (functionName, parameters) async => <String, dynamic>{
            'intentId': 'query_low_stock',
            'level': 3,
          },
        );

        expect(await parser.parse('quels produits sont bas'), isNull);

        final ParseRouteEvent event = journal.events.single;
        expect(event.reason, ParseRouteReason.malformedAnswer);
        expect(event.reason, isNot(ParseRouteReason.unreachable));
        expect(event.detail, isNotEmpty);
      },
    );

    test('distingue aussi une intention qui nest pas du texte', () async {
      parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        journal: journal,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 42,
        },
      );

      expect(await parser.parse('quels produits sont bas'), isNull);

      final ParseRouteEvent event = journal.events.single;
      expect(event.reason, ParseRouteReason.malformedAnswer);
      expect(event.reason, isNot(ParseRouteReason.noIntentReturned));
    });

    test('laisse un appel casse etre injoignable', () async {
      parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        journal: journal,
        cloudCaller: (functionName, parameters) async =>
            throw Exception('Connection refused'),
      );

      expect(await parser.parse('quels produits sont bas'), isNull);

      expect(journal.events.single.reason, ParseRouteReason.unreachable);
    });

    test('fonctionne sans journal', () async {
      final RemoteCloudIntentParser sansJournal = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{},
      );

      expect(await sansJournal.parse('bonjour'), isNull);
    });
  });

  group('une passerelle ne masque plus son echec', () {
    test('laisse remonter un echec de passerelle', () async {
      final RodiumAiCaller caller = RodiumAiCaller(
        apiKey: 'rd_sk_test',
        systemPrompt: 'PROMPT',
        httpPoster:
            (
              uri,
              headers,
              body, {
              timeout = const Duration(seconds: 2),
            }) async =>
                throw const CloudCallFailure('Rodium AI HTTP 401: refusee'),
      );

      expect(
        () => caller.call('interpretUtterance', <String, dynamic>{}),
        throwsA(isA<CloudCallFailure>()),
      );
    });

    test('garde la reponse vide quand l appel echoue vraiment', () async {
      final RodiumAiCaller caller = RodiumAiCaller(
        apiKey: 'rd_sk_test',
        systemPrompt: 'PROMPT',
        httpPoster:
            (
              uri,
              headers,
              body, {
              timeout = const Duration(seconds: 2),
            }) async => throw Exception('Connection refused'),
      );

      expect(
        await caller.call('interpretUtterance', <String, dynamic>{}),
        isEmpty,
      );
    });

    test('decrit une reponse HTTP par son code et un extrait', () {
      expect(
        CloudCallFailure.fromResponse('Rodium AI', 401, 'cle refusee').detail,
        equals('Rodium AI HTTP 401: cle refusee'),
      );
      expect(
        CloudCallFailure.fromResponse('Gemini', 500, '').detail,
        equals('Gemini HTTP 500'),
      );
    });

    test('coupe un corps trop long plutot que de noyer le journal', () {
      final CloudCallFailure failure = CloudCallFailure.fromResponse(
        'Rodium AI',
        500,
        'x' * 5000,
      );

      expect(
        failure.detail.length,
        lessThan(CloudCallFailure.kBodyExcerptLimit + 64),
      );
      expect(failure.detail, endsWith('...'));
    });
  });
}
