import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/localization/generated/app_localizations.dart';
import 'package:kiosk_mind/core/voice_services/speech_service_error.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/clarification_slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_message.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_message_text.dart';

/// The one sentence the screen shows and the module says.
///
/// Every kind of message is written here, so every kind is checked here: a table
/// over the facts of [VoiceMessage] and the French they produce. The panel tests
/// prove the sentence reaches the screen and the voice; this one proves the French
/// is right, which they cannot show because they match on fragments.
AppLocalizations french() => lookupAppLocalizations(const Locale('fr'));

VoiceMessage questionOf(ClarificationSlot slot) =>
    QuestionMessage(doubt: DoubtKind.missingQuantity, slot: slot);

void main() {
  late AppLocalizations l10n;

  setUp(() => l10n = french());

  group('the questions', () {
    const List<(ClarificationSlot, String)> cases =
        <(ClarificationSlot, String)>[
          (ClarificationSlot.productName, 'Quel produit ?'),
          (
            ClarificationSlot.itemProductName,
            'Quel produit pour la première ligne ?',
          ),
          (ClarificationSlot.itemQty, 'Combien ?'),
          (ClarificationSlot.confirmed, 'Vous confirmez ?'),
        ];

    for (final (ClarificationSlot slot, String text) in cases) {
      test('${slot.name} is asked as "$text"', () {
        expect(voiceMessageText(l10n, questionOf(slot)), text);
      });
    }
  });

  group('the answers', () {
    test('a sale is read with its lines and its total in words', () {
      const SaleRecorded sale = SaleRecorded(
        lines: <VoiceRecapLine>[
          (name: 'Savon de ménage', qty: 2, unit: 'PIECE'),
          (name: 'Riz parfumé', qty: 1, unit: 'KG'),
        ],
        total: 750,
      );

      expect(
        voiceMessageText(l10n, const DoneMessage(sale)),
        '2 lignes enregistrées - deux pièces de Savon de ménage, un kilogramme '
        'de Riz parfumé - total sept cent cinquante francs',
      );
    });

    test('a restock has no unit to say, so it says none', () {
      const RestockRecorded restock = RestockRecorded(<VoiceRecapLine>[
        (name: 'Sucre', qty: 10, unit: null),
      ]);

      expect(
        voiceMessageText(l10n, const DoneMessage(restock)),
        'Une ligne de réappro - dix de Sucre',
      );
    });

    test('a stock answer names the product and its unit', () {
      const StockRead read = StockRead(
        product: 'Huile de palme',
        stock: 5,
        unit: 'LITRE',
      );

      expect(
        voiceMessageText(l10n, const DoneMessage(read)),
        'Huile de palme : cinq litres',
      );
    });

    test('a cancelled sale says so', () {
      const SaleCancelled cancelled = SaleCancelled(<VoiceRecapLine>[
        (name: 'Sucre', qty: 1, unit: 'SACHET'),
      ]);

      expect(
        voiceMessageText(l10n, const UndoneMessage(cancelled)),
        'Vente annulée',
      );
    });

    test('a refusal, an undo failure and a nothing to undo each say it', () {
      expect(
        voiceMessageText(l10n, const RefusalMessage(DoubtKind.outOfDomain)),
        'Je ne peux pas faire cela',
      );
      expect(
        voiceMessageText(l10n, const UndoFailedMessage()),
        'Annulation impossible',
      );
      expect(
        voiceMessageText(l10n, const NothingToUndoMessage()),
        'Rien à annuler',
      );
    });

    test('a microphone that cannot be used says which fault it is', () {
      expect(
        voiceMessageText(
          l10n,
          const MicUnavailableMessage(SpeechFault.permissionDenied),
        ),
        contains('Micro autorisé'),
      );
      expect(
        voiceMessageText(
          l10n,
          const MicUnavailableMessage(SpeechFault.unsupported),
        ),
        'Micro indisponible',
      );
    });

    test('the manual route is named on screen too', () {
      expect(
        voiceMessageText(l10n, const ManualEntryMessage()),
        'Saisie manuelle',
      );
    });
  });

  group('the quantities', () {
    test('a whole number is said in words, a decimal keeps its digits', () {
      expect(
        voiceMessageText(
          l10n,
          const DoneMessage(
            StockRead(product: 'Sucre', stock: 1.5, unit: 'KG'),
          ),
        ),
        'Sucre : 1,5 kilogrammes',
      );
      expect(
        voiceMessageText(
          l10n,
          const DoneMessage(
            StockRead(product: 'Sucre', stock: 0.25, unit: 'KG'),
          ),
        ),
        'Sucre : 0,25 kilogramme',
      );
    });

    test('a unit the catalog does not name falls back to the piece', () {
      expect(
        voiceMessageText(
          l10n,
          const DoneMessage(
            StockRead(product: 'Ciment 50 kg', stock: 1, unit: 'PALETTE'),
          ),
        ),
        'Ciment 50 kg : une pièce',
      );
    });

    test('every unit code of the catalog is said the way a shop says it', () {
      const List<(String, String)> units = <(String, String)>[
        ('PIECE', 'une pièce'),
        ('KG', 'un kilogramme'),
        ('LITRE', 'un litre'),
        ('SACHET', 'un sachet'),
        ('SAC', 'un sac'),
        ('BOITE', 'une boîte'),
        ('PALETTE', 'une pièce'),
        ('piece', 'une pièce'),
      ];

      for (final (String code, String unit) in units) {
        expect(
          voiceMessageText(
            l10n,
            DoneMessage(StockRead(product: 'Article', stock: 1, unit: code)),
          ),
          'Article : $unit',
          reason: code,
        );
      }
    });

    test('a quantity of several drops the article and pluralises', () {
      const List<(String, double, String)> units = <(String, double, String)>[
        ('PIECE', 2, 'deux pièces'),
        ('KG', 3, 'trois kilogrammes'),
        ('LITRE', 5, 'cinq litres'),
        ('SACHET', 3, 'trois sachets'),
        ('SAC', 2, 'deux sacs'),
        ('BOITE', 2, 'deux boîtes'),
      ];

      for (final (String code, double qty, String unit) in units) {
        expect(
          voiceMessageText(
            l10n,
            DoneMessage(StockRead(product: 'Article', stock: qty, unit: code)),
          ),
          'Article : $unit',
          reason: code,
        );
      }
    });

    test('a zero and a fraction are singular, the way French counts them', () {
      expect(
        voiceMessageText(
          l10n,
          const DoneMessage(
            StockRead(product: 'Sucre', stock: 0, unit: 'SACHET'),
          ),
        ),
        'Sucre : zéro sachet',
      );
      expect(
        voiceMessageText(
          l10n,
          const DoneMessage(
            StockRead(product: 'Sucre', stock: 0.25, unit: 'KG'),
          ),
        ),
        'Sucre : 0,25 kilogramme',
      );
    });

    test('a quantity of several is said in the plural', () {
      expect(
        voiceMessageText(
          l10n,
          const DoneMessage(
            StockRead(product: 'Sucre', stock: 3, unit: 'SACHET'),
          ),
        ),
        'Sucre : trois sachets',
      );
    });
  });
}
