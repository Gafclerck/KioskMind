import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/errors/failure.dart';
import 'package:kiosk_mind/core/usecase/result.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/journaling_intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_cancel_last_sale_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_voice_handlers.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/dialog/dialog_manager.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_id_factory.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';

import 'fake_clock.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/execute_command.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/undo_last_command.dart';

/// Running a decided proposal, and taking it back.
///
/// The journal is the evidence: what the merchant said becomes a call to exactly
/// one handler, with exactly the arguments the merchant gave. Nothing here
/// inspects the shop state, because a handler does that and reports failures of
/// its own.
void main() {
  late _Shop shop;

  setUp(() => shop = _Shop());

  group('routage', () {
    test('une vente appelle le handler de vente', () async {
      final CommandExecution execution = await shop.execute(
        DecisionOutcome.executeWithUndo,
        _sale(<ItemMention>[_line('sucre', 3)]),
      );

      expect(execution.isExecuted, isTrue);
      expect(execution.failure, isNull);
      expect(shop.journal.calls, hasLength(1));
      expect(shop.journal.calls.single.intentId, 'record_sale');
      expect(shop.journal.calls.single.handlerArgs, <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'productId': 'sucre', 'qty': 3},
        ],
      });
    });

    test(
      'un approvisionnement appelle le handler d approvisionnement',
      () async {
        await shop.execute(
          DecisionOutcome.executeWithUndo,
          _proposal('record_restock', <ItemMention>[_line('sucre', 2, 75)]),
        );

        expect(shop.journal.calls.single.intentId, 'record_restock');
      },
    );

    test('une question de stock appelle le handler de lecture', () async {
      await shop.execute(
        DecisionOutcome.execute,
        _proposal('query_stock', null, productId: 'sucre'),
      );

      expect(shop.journal.calls.single.intentId, 'query_stock');
      expect(shop.journal.calls.single.handlerArgs, <String, Object?>{
        'productId': 'sucre',
      });
    });

    test('une multi-ligne garde l ordre parle', () async {
      await shop.execute(
        DecisionOutcome.executeWithUndo,
        _sale(<ItemMention>[_line('sucre', 2), _line('lait', 1)]),
      );

      final List<Object?> items =
          shop.journal.calls.single.handlerArgs['items']! as List<Object?>;
      expect(items, hasLength(2));
      expect(
        (items.first! as Map<String, Object?>)['productId'],
        'sucre',
        reason: 'l ordre de la parole fait foi',
      );
    });

    test('le cout parle ne va que sur un approvisionnement', () async {
      await shop.execute(
        DecisionOutcome.executeWithUndo,
        _proposal('record_restock', <ItemMention>[_line('riz', 5, 700)]),
      );
      expect(
        (shop.journal.calls.single.handlerArgs['items']! as List<Object?>)
            .first,
        <String, Object?>{'productId': 'riz', 'qty': 5, 'unitCost': 700},
      );

      await shop.execute(
        DecisionOutcome.executeWithUndo,
        _sale(<ItemMention>[_line('riz', 5, 700)]),
      );
      expect(
        (shop.journal.calls.last.handlerArgs['items']! as List<Object?>).first,
        <String, Object?>{'productId': 'riz', 'qty': 5},
        reason: 'un prix de vente annonce est un doute, pas un argument',
      );
    });
  });

  group('ce qui ne s execute pas', () {
    test('une question n appelle aucun handler', () async {
      final CommandExecution execution = await shop.execute(
        DecisionOutcome.askConfirmation,
        _sale(<ItemMention>[_line('sucre', 30)]),
      );

      expect(execution.isExecuted, isFalse);
      expect(shop.journal.calls, isEmpty);
    });

    test('un refus n appelle aucun handler', () async {
      final CommandExecution execution = await shop.execute(
        DecisionOutcome.reject,
        _proposal('record_sale', <ItemMention>[_line('sucre', 1)]),
      );

      expect(execution.isExecuted, isFalse);
      expect(shop.journal.calls, isEmpty);
    });

    test('un intent sans handler branche est une erreur franche', () async {
      // Un intent du catalogue sans port ne doit pas disparaitre dans un silence:
      // le catalogue le refuse au chargement, donc ici c'est un câblage casse.
      final ExecuteCommand executor = ExecuteCommand(
        handlers: const VoiceHandlers(),
        dialog: shop.dialog,
        clock: shop.clock,
        ids: _SequentialIds(),
        undo: shop.undoer,
      );

      await expectLater(
        executor.run(
          decision: const Decision(DecisionOutcome.execute),
          proposal: _sale(<ItemMention>[_line('sucre', 1)]),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        shop.journal.calls,
        isEmpty,
        reason: 'un handler absent ne laisse rien passer',
      );
    });
  });

  group('echecs', () {
    test('un echec du use case remonte tel quel', () async {
      // Le produit vient de la proposition, donc un identifiant absent du
      // catalogue atteint le use case et en revient refuse, avec son type: la
      // couche vocale ne traduit pas l echec en silence.
      final CommandExecution execution = await shop.execute(
        DecisionOutcome.executeWithUndo,
        _sale(<ItemMention>[_line('inexistant', 1)]),
      );

      expect(execution.isExecuted, isTrue, reason: 'le handler a repondu');
      expect(execution.failure, isA<UnknownProduct>());
      expect(shop.catalog.saleById('cmd-1'), isNull, reason: 'rien n ecrit');
    });

    test('une vente rejouee ne s ecrit pas deux fois', () async {
      // Un rejeu, c'est le meme identifiant de commande: le store renvoie le
      // premier resultat au lieu d'ecrire une seconde fois.
      final _Shop replayed = _Shop(commandIds: _FixedIds());
      final CommandProposal proposal = _sale(<ItemMention>[_line('sucre', 3)]);

      final CommandExecution first = await replayed.execute(
        DecisionOutcome.executeWithUndo,
        proposal,
      );
      final CommandExecution again = await replayed.execute(
        DecisionOutcome.executeWithUndo,
        proposal,
      );

      expect(first.failure, isNull);
      expect(again.failure, isNull);
      expect(replayed.catalog.stockOf('sucre'), 37);
      expect(first.result, isA<Success<RecordSaleResult>>());
    });
  });

  group('fenetre d annulation', () {
    test(
      'une vente ouvre une fenetre sur la vente qu elle vient de faire',
      () async {
        await shop.execute(
          DecisionOutcome.executeWithUndo,
          _sale(<ItemMention>[_line('sucre', 3)]),
        );

        expect(shop.dialog.undoSaleId, 'cmd-1');
        expect(shop.dialog.remainingUndo, const Duration(seconds: 10));
      },
    );

    test('une lecture n ouvre aucune fenetre', () async {
      await shop.execute(
        DecisionOutcome.execute,
        _proposal('query_stock', null, productId: 'sucre'),
      );

      expect(shop.dialog.undoSaleId, isNull);
    });

    test(
      'une commande confirmee n ouvre la fenetre qu une fois confirmee',
      () async {
        final CommandExecution held = await shop.execute(
          DecisionOutcome.askConfirmation,
          _sale(<ItemMention>[_line('sucre', 30)]),
        );

        expect(held.isExecuted, isFalse);
        expect(shop.dialog.undoSaleId, isNull);
        expect(shop.journal.calls, isEmpty);
      },
    );
  });

  group('annulation', () {
    Future<void> sellOne(double qty) => shop.execute(
      DecisionOutcome.executeWithUndo,
      _sale(<ItemMention>[_line('sucre', qty)]),
    );

    test('annuler passe par le handler d annulation', () async {
      await sellOne(3);
      shop.journal.clear();

      final Result<CancelLastSaleResult> result = await shop.undo();

      expect(result, isA<Success<CancelLastSaleResult>>());
      expect(shop.journal.calls.single.intentId, 'cancel_last_sale');
      expect(shop.journal.calls.single.handlerArgs, <String, Object?>{
        'saleId': 'cmd-1',
      });
    });

    test('annuler rend le stock et ne supprime rien', () async {
      await sellOne(3);
      expect(shop.catalog.stockOf('sucre'), 37);

      await shop.undo();

      expect(shop.catalog.stockOf('sucre'), 40);
      expect(
        shop.catalog.saleById('cmd-1'),
        isNotNull,
        reason: 'une annulation logique ne supprime pas la vente',
      );
      expect(shop.catalog.saleById('cmd-1')!.cancelledAt, isNotNull);
    });

    test('rien a annuler est un echec nomme, pas une execution vide', () async {
      final Result<CancelLastSaleResult> result = await shop.undo();

      expect(result, isA<Failed<CancelLastSaleResult>>());
      expect(
        (result as Failed<CancelLastSaleResult>).failure,
        isA<NothingToUndo>(),
      );
      expect(shop.journal.calls, isEmpty);
    });

    test('annuler deux fois echoue', () async {
      await sellOne(3);
      await shop.undo();
      shop.journal.clear();

      final Result<CancelLastSaleResult> second = await shop.undo();

      expect(second, isA<Failed<CancelLastSaleResult>>());
      expect(shop.journal.calls, isEmpty);
    });

    test('une fenetre fermee ne s annule plus', () async {
      await sellOne(3);
      shop.clock.elapse(const Duration(seconds: 11));

      final Result<CancelLastSaleResult> result = await shop.undo();

      expect(result, isA<Failed<CancelLastSaleResult>>());
      expect(shop.catalog.stockOf('sucre'), 37, reason: 'la vente reste faite');
    });

    test('une annulation par la voix prend la derniere vente', () async {
      await sellOne(3);
      shop.journal.clear();

      final CommandExecution execution = await shop.execute(
        DecisionOutcome.executeWithUndo,
        _proposal('cancel_last_sale', null, saleId: r'$lastSaleId'),
      );

      expect(execution.isExecuted, isTrue);
      expect(shop.journal.calls.single.handlerArgs, <String, Object?>{
        'saleId': 'cmd-1',
      });
      expect(shop.catalog.stockOf('sucre'), 40);
    });

    test('une annulation par la voix ne s annule pas elle-meme', () async {
      // "annule" est le mot d annulation: le prendre pour une vente
      // l annulerait puis l annulerait, deux fois.
      await sellOne(3);

      final CommandExecution execution = await shop.execute(
        DecisionOutcome.executeWithUndo,
        _proposal('cancel_last_sale', null, saleId: r'$lastSaleId'),
      );

      expect(execution.isExecuted, isTrue);
      expect(shop.catalog.saleById('cmd-1')!.cancelledAt, isNotNull);
      expect(shop.dialog.undoSaleId, isNull);
    });

    test('une annulation par la voix laisse la vente venue', () async {
      // Une annulation n'ouvre pas de nouvelle fenetre: la vente qu'elle vise
      // vient d'etre annulee, il n'y a plus rien derriere elle a prendre.
      final CommandExecution execution = await shop.execute(
        DecisionOutcome.executeWithUndo,
        _proposal('cancel_last_sale', null, saleId: r'$lastSaleId'),
      );

      expect(execution.isExecuted, isTrue);
      expect(shop.dialog.undoSaleId, isNull);
      expect(
        shop.catalog.stockOf('sucre'),
        40,
        reason: 'rien n avait ete vendu',
      );
    });

    // Les deux voies d'entree doivent se comporter pareil. Avant, "annule" dit a
    // voix consommait la fenetre pour de bon alors que le bouton la rendait : le
    // commerçant qui lossesait la voix perdait le seul moyen de reessayer.
    group('un echec du handler ne ferme pas la fenetre', () {
      // Les deux voies d'entree doivent se comporter pareil. Avant, "annule" dit a
      // voix consommait la fenetre pour de bon alors que le bouton la rendait : le
      // commerçant qui passait par la voix perdait le seul moyen de reessayer.
      late _Shop failing;

      setUp(() async {
        failing = _Shop(cancelFails: true);
        await failing.execute(
          DecisionOutcome.executeWithUndo,
          _sale(<ItemMention>[_line('sucre', 3)]),
        );
      });

      test('la voie du bouton rend la fenetre', () async {
        await failing.undo();

        expect(
          failing.dialog.undoSaleId,
          'cmd-1',
          reason: 'le commerçant doit pouvoir reessayer',
        );
      });

      test('la voie de la voix rend la fenetre aussi', () async {
        await failing.execute(
          DecisionOutcome.executeWithUndo,
          _proposal('cancel_last_sale', null, saleId: r'$lastSaleId'),
        );

        expect(
          failing.dialog.undoSaleId,
          'cmd-1',
          reason: 'la meme action doit laisser le meme etat derriere elle',
        );
      });

      test('la vente reste faite quand l annulation echoue', () async {
        await failing.execute(
          DecisionOutcome.executeWithUndo,
          _proposal('cancel_last_sale', null, saleId: r'$lastSaleId'),
        );

        expect(failing.catalog.saleById('cmd-1')!.cancelledAt, isNull);
        expect(failing.catalog.stockOf('sucre'), 37);
      });

      test('un reussite ne rend pas la fenetre', () async {
        final _Shop working = _Shop();
        await working.execute(
          DecisionOutcome.executeWithUndo,
          _sale(<ItemMention>[_line('sucre', 3)]),
        );

        await working.undo();

        expect(
          working.dialog.undoSaleId,
          isNull,
          reason: 'la vente est annulee, il n y a plus rien a reprendre',
        );
      });
    });
  });

  test('le journal ne melange pas deux commandes', () async {
    await shop.execute(
      DecisionOutcome.executeWithUndo,
      _sale(<ItemMention>[_line('sucre', 2)]),
    );
    await shop.execute(
      DecisionOutcome.execute,
      _proposal('query_stock', null, productId: 'lait'),
    );

    expect(shop.journal.calls.map((HandlerCall c) => c.intentId), <String>[
      'record_sale',
      'query_stock',
    ]);
  });
}

CommandProposal _proposal(
  String intent,
  List<ItemMention>? items, {
  String? productId,
  String? saleId,
}) {
  return CommandProposal.rules(
    intentId: intent,
    slots: <Slot>[
      if (items != null) Slot(name: 'items', value: items),
      if (productId != null) Slot(name: 'productId', value: productId),
      if (saleId != null) Slot(name: 'saleId', value: saleId),
    ],
  );
}

CommandProposal _sale(List<ItemMention> items) =>
    _proposal('record_sale', items);

ItemMention _line(String productId, double qty, [double? amount]) {
  return ItemMention(
    product: _Shop.product(productId),
    qty: qty,
    spokenAmount: amount,
  );
}

/// The shop the executor runs against, plus the evidence it produces.
final class _Shop {
  _Shop({this.commandIds, this.cancelFails = false});

  /// A factory that hands back the same identifier, which is what a replay is.
  final CommandIdFactory? commandIds;

  /// Makes the cancellation handler refuse, which is what a sale already
  /// cancelled, or a write the shop refused, looks like to the session.
  final bool cancelFails;

  final FakeClock clock = FakeClock(DateTime(2026, 3, 14, 8));
  late final InMemoryProductCatalog catalog = InMemoryProductCatalog(
    _Shop.products(),
  );
  late final HandlerCallJournal journal = InMemoryCallJournal();
  late final VoiceHandlers _working = buildMockVoiceHandlers(
    catalog: catalog,
    journal: journal,
  );
  late final VoiceHandlers handlers = VoiceHandlers(
    recordSale: _working.recordSale,
    recordRestock: _working.recordRestock,
    queryStock: _working.queryStock,
    cancelLastSale:
        JournalingIntentHandler<CancelLastSaleInput, CancelLastSaleResult>(
          cancelFails
              ? const _RefusingCancelHandler()
              : MockCancelLastSaleHandler(catalog),
          journal,
        ),
  );
  late final DialogManager dialog = DialogManager(
    config: const VoiceConfig(),
    clock: clock,
  );
  late final UndoLastCommand undoer = UndoLastCommand(
    handlers: handlers,
    dialog: dialog,
    clock: clock,
    ids: _SequentialIds(prefix: 'undo-'),
  );
  late final ExecuteCommand runner = ExecuteCommand(
    handlers: handlers,
    dialog: dialog,
    clock: clock,
    ids: commandIds ?? _SequentialIds(),
    undo: undoer,
  );

  /// Undoes the last write, the way the undo banner does.
  Future<Result<CancelLastSaleResult>> undo() => undoer.run();

  /// Runs a proposal the way the orchestrator does: the policy has already
  /// decided, so the test states the outcome and the proposal, never the policy.
  Future<CommandExecution> execute(
    DecisionOutcome outcome,
    CommandProposal proposal,
  ) {
    return runner.run(decision: Decision(outcome), proposal: proposal);
  }

  static List<ProductSnapshot> products() => <ProductSnapshot>[
    product('sucre', price: 100, purchasePrice: 75, stock: 40),
    product('lait', price: 200, purchasePrice: 155, stock: 12),
    product('riz', price: 700, purchasePrice: 560, stock: 5),
  ];

  static ProductSnapshot product(
    String id, {
    double price = 100,
    double? purchasePrice,
    double stock = 40,
  }) {
    return ProductSnapshot(
      id: id,
      name: id,
      aliases: const <String>[],
      unit: 'PIECE',
      price: price,
      purchasePrice: purchasePrice,
      stock: stock,
      alertThreshold: 0,
      averageDailyQty: 0,
    );
  }
}

/// A cancellation the shop refuses, whatever the session still has open.
///
/// Stands for a sale already cancelled, or a write the shop did not accept: the
/// words were understood, the action did not happen.
final class _RefusingCancelHandler
    implements IntentHandler<CancelLastSaleInput, CancelLastSaleResult> {
  const _RefusingCancelHandler();

  @override
  String get intentId => 'cancel_last_sale';

  @override
  Future<Result<CancelLastSaleResult>> execute(
    CommandContext context,
    CancelLastSaleInput input,
  ) {
    return Future<Result<CancelLastSaleResult>>.value(
      Failed<CancelLastSaleResult>(AlreadyCancelled(input.saleId)),
    );
  }
}

/// Command identifiers the test reads back, so nothing depends on a real uuid.
final class _SequentialIds implements CommandIdFactory {
  _SequentialIds({this.prefix = 'cmd-'});

  final String prefix;
  int _count = 0;

  @override
  String next() => '$prefix${++_count}';
}

/// Always the same identifier, to replay a command deliberately.
final class _FixedIds implements CommandIdFactory {
  @override
  String next() => 'cmd-1';
}
