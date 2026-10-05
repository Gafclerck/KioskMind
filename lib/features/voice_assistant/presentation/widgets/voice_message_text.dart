import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/voice_services/speech_service_error.dart';
import '../../domain/entities/clarification_slot.dart';
import '../../domain/services/spoken_amount_formatter.dart';
import '../state/voice_message.dart';
import '../state/voice_outcome.dart';
import '../state/voice_recap.dart';

/// The sentence the merchant reads, or the one the module speaks.
///
/// One text for both, and it is a fact the contract fixes rather than a choice:
/// the recap is always shown and always said, so producing it twice would let the
/// screen and the voice drift apart the first time one of them is changed.
///
/// Everything a locale needs is decided here from the facts in [message]. A string
/// that is not a fact of a message cannot be written here, which is what keeps the
/// domain free of French.
String voiceMessageText(AppLocalizations l10n, VoiceMessage message) {
  final SpokenAmountFormatter formatter = const SpokenAmountFormatter();
  return switch (message) {
    QuestionMessage() => _questionText(l10n, message),
    RefusalMessage() => l10n.voiceRefused,
    DoneMessage(
      outcome: final VoiceOutcome outcome,
      customSpeechText: final String? customText,
    ) =>
      customText != null && customText.isNotEmpty
          ? customText
          : _outcomeText(l10n, outcome, formatter),
    UndoneMessage(
      outcome: final VoiceOutcome _,
      customSpeechText: final String? customText,
    ) =>
      customText != null && customText.isNotEmpty
          ? customText
          : l10n.voiceSaleCancelled,
    NothingToUndoMessage() => l10n.voiceNothingToUndo,
    UndoFailedMessage() => l10n.voiceUndoFailed,
    MicUnavailableMessage(fault: final Object fault) =>
      fault == SpeechFault.permissionDenied
          ? l10n.voiceMicRefused
          : l10n.voiceMicUnavailable,
    ManualEntryMessage() => l10n.voiceManualTitle,
  };
}

/// The command a confirmation is about, as one sentence.
///
/// The same facts and the same wording as the recap read after the command runs,
/// because a merchant who is asked to authorise "create the product X at 500" and
/// then hears "the price of X was updated to 500" was not asked the question he
/// answered. An operation with nothing to read returns an empty string, and the
/// screen shows the transcript instead of an empty confirmation.
String voiceRecapText(
  AppLocalizations l10n,
  VoiceRecap recap,
  SpokenAmountFormatter amounts,
) {
  final List<String> parts = <String>[
    for (final VoiceRecapLine line in recap.lines)
      _recapLine(l10n, line, amounts),
    for (final VoiceRecapDetail detail in recap.details)
      if (_recapDetail(l10n, recap, detail, amounts) case final String said)
        said,
  ];
  if (parts.isEmpty) {
    return '';
  }
  final String operation = _operationText(l10n, recap.intentId);
  return parts.length == 1
      ? '$operation : ${parts.first}'
      : '$operation : ${parts.join(', ')}';
}

/// The name of the operation, as the locale names it.
///
/// Keyed by the catalog identifier rather than by a word, so renaming an intent in
/// the catalog cannot leave a confirmation calling it by its old name: an
/// identifier nothing knows falls back to the generic wording, which is a weaker
/// sentence and never a wrong one.
String _operationText(AppLocalizations l10n, String intentId) {
  return switch (intentId) {
    'record_sale' => l10n.voiceRecapOperationSale,
    'record_restock' => l10n.voiceRecapOperationRestock,
    'cancel_last_sale' => l10n.voiceRecapOperationCancel,
    'record_stock_out' => l10n.voiceRecapOperationStockOut,
    'create_product' => l10n.voiceRecapOperationCreateProduct,
    'update_product_price' => l10n.voiceRecapOperationUpdatePrice,
    'navigate_to_page' => l10n.voiceRecapOperationNavigate,
    'export_sales_report' => l10n.voiceRecapOperationExport,
    'query_daily_stats' => l10n.voiceRecapOperationDailyStats,
    'query_low_stock' => l10n.voiceRecapOperationLowStock,
    'query_product_price' => l10n.voiceRecapOperationProductPrice,
    'query_sales_history' => l10n.voiceRecapOperationSalesHistory,
    'query_business_info' => l10n.voiceRecapOperationBusinessInfo,
    'query_stock' => l10n.voiceRecapOperationStock,
    _ => l10n.voiceRecapOperationGeneric,
  };
}

/// One product of a recap.
///
/// A line with no count is a product the command names rather than moves, so it is
/// said as the name alone: "two units of sugar" for a question about the price of
/// sugar would be a quantity the merchant never said.
String _recapLine(
  AppLocalizations l10n,
  VoiceRecapLine line,
  SpokenAmountFormatter amounts,
) {
  if (line.qty == 0) {
    return line.name;
  }
  final String? unit = line.unit;
  if (unit == null) {
    return l10n.voiceRecapLinePlain(_quantity(line.qty, amounts), line.name);
  }
  return l10n.voiceRecapLine(
    _qtyWithUnit(l10n, line.qty, unit, amounts),
    line.name,
  );
}

/// One value of a recap, or null when it has nothing worth saying.
///
/// A detail the merchant did not give is skipped rather than read as a blank, so a
/// confirmation never asks him to agree to a value that was never spoken.
String? _recapDetail(
  AppLocalizations l10n,
  VoiceRecap recap,
  VoiceRecapDetail detail,
  SpokenAmountFormatter amounts,
) {
  final double? amount = detail.amount;
  if (amount != null) {
    final String spoken = '${amounts(amount)} ${l10n.voiceCurrency}';
    return switch (detail.key) {
      'spokenAmount' => detail.text == null
          ? spoken
          : l10n.voiceRecapAmountFor(detail.text!, spoken),
      'newPrice' => l10n.voiceRecapNewPrice(spoken),
      'price' => l10n.voiceRecapPrice(spoken),
      'purchasePrice' => l10n.voiceRecapPurchasePrice(spoken),
      'qty' => l10n.voiceRecapQuantity(_quantity(amount, amounts)),
      'initialQty' => l10n.voiceRecapInitialQty(_quantity(amount, amounts)),
      _ => spoken,
    };
  }
  final String? text = detail.text;
  if (text == null || text.isEmpty) {
    return null;
  }
  return switch (detail.key) {
    'name' => l10n.voiceRecapProductName(text),
    'reason' => l10n.voiceRecapReason(_reasonText(l10n, text)),
    'note' => l10n.voiceRecapNote(text),
    'destination' => l10n.voiceRecapDestination(_destinationText(l10n, text)),
    'format' => l10n.voiceRecapFormat(text.toUpperCase()),
    'period' => l10n.voiceRecapPeriod(_periodText(l10n, text)),
    'date' => l10n.voiceRecapDate(_dateText(l10n, text)),
    'level' => l10n.voiceRecapLevel(_levelText(l10n, text)),
    'limit' => l10n.voiceRecapLimit(text),
    _ => text,
  };
}

/// The reason a stock loss is given, said in French rather than as a code.
///
/// The reason reaches the handler as a machine word because that is what the
/// catalog and the movement use. Spoken and shown, it is a word the merchant
/// chose, and a code read aloud is a word he did not choose. A reason the module
/// does not know is read as it arrived rather than dropped, because losing the
/// reason is worse than saying an unfamiliar one.
String _reasonText(AppLocalizations l10n, String reason) {
  return switch (reason.toLowerCase()) {
    'breakage' || 'casse' || 'abime' => l10n.voiceReasonBreakage,
    'loss' || 'perte' || 'perime' || 'peremption' || 'expired' || 'avarie' =>
      l10n.voiceReasonLoss,
    'donation' || 'don' => l10n.voiceReasonDonation,
    'manualadjustment' || 'ajustement' => l10n.voiceReasonAdjustment,
    'personal_use' || 'usage_personnel' => l10n.voiceReasonPersonalUse,
    _ => reason,
  };
}

/// The screen a navigation goes to, as the locale names it.
String _destinationText(AppLocalizations l10n, String destination) {
  return switch (destination.toLowerCase()) {
    'dashboard' || 'accueil' => l10n.voiceDestinationDashboard,
    'stock' || 'produit' || 'produits' || 'inventaire' || 'catalogue' =>
      l10n.voiceDestinationStock,
    'sales_history' || 'historique' || 'journal' || 'ventes' =>
      l10n.voiceDestinationSalesHistory,
    'profile' || 'profil' || 'compte' || 'parametre' || 'parametres' =>
      l10n.voiceDestinationProfile,
    _ => destination,
  };
}

/// The span an export covers, as the locale names it.
String _periodText(AppLocalizations l10n, String period) {
  return switch (period.toLowerCase()) {
    'day' || 'jour' => l10n.voicePeriodDay,
    'week' || 'semaine' => l10n.voicePeriodWeek,
    'month' || 'mois' => l10n.voicePeriodMonth,
    'all' || 'tout' || 'total' => l10n.voicePeriodAll,
    _ => period,
  };
}

/// The day a question is about, as the locale names it.
String _dateText(AppLocalizations l10n, String date) {
  return switch (date.toLowerCase()) {
    'today' || "aujourd'hui" => l10n.voiceDateToday,
    'yesterday' || 'hier' => l10n.voiceDateYesterday,
    _ => date,
  };
}

/// How low a stock question asks, as the locale names it.
String _levelText(AppLocalizations l10n, String level) {
  return switch (level.toLowerCase()) {
    'out_of_stock' || 'rupture' || 'outofstock' => l10n.voiceLevelOutOfStock,
    'low_stock' || 'critical' || 'faible' || 'bas' => l10n.voiceLevelLow,
    'all' || 'tout' => l10n.voiceLevelAll,
    _ => level,
  };
}

/// The question the session is waiting on, asked in its own words.
String _questionText(AppLocalizations l10n, QuestionMessage question) {
  return switch (question.slot) {
    ClarificationSlot.productName => l10n.voiceQuestionProduct,
    ClarificationSlot.itemProductName => l10n.voiceQuestionProductInLine,
    ClarificationSlot.itemQty => l10n.voiceQuestionQuantity,
    ClarificationSlot.confirmed => l10n.voiceQuestionConfirm,
  };
}

/// What a command did, as one sentence.
String _outcomeText(
  AppLocalizations l10n,
  VoiceOutcome outcome,
  SpokenAmountFormatter amounts,
) {
  return switch (outcome) {
    final SaleRecorded sale => _withTotal(
      l10n,
      '${l10n.voiceSaleDone(sale.lines.length)} - ${_lines(l10n, sale.lines, amounts)}',
      amounts,
      sale.total,
    ),
    final RestockRecorded restock =>
      '${l10n.voiceRestockDone(restock.lines.length)} - ${_lines(l10n, restock.lines, amounts)}',
    final StockRead stock => l10n.voiceStockRead(
      stock.product,
      _qtyWithUnit(l10n, stock.stock, stock.unit, amounts),
    ),
    SaleCancelled() => l10n.voiceSaleCancelled,
    final DailyStatsRead stats => _dailyStatsText(l10n, stats, amounts),
    final LowStockRead lowStock => _lowStockText(l10n, lowStock, amounts),
    final ProductPriceRead price => _productPriceText(l10n, price, amounts),
    final StockOutRecorded stockOut => _stockOutText(l10n, stockOut, amounts),
    final PageNavigated nav => _pageNavigatedText(l10n, nav),
    final ReportExported report => _reportExportedText(l10n, report),
    final ProductCreated created => _productCreatedText(l10n, created, amounts),
    final ProductPriceUpdated updated => _productPriceUpdatedText(
      l10n,
      updated,
      amounts,
    ),
    final SalesHistoryRead history => _salesHistoryText(l10n, history, amounts),
    final BusinessInfoRead info => _businessInfoText(l10n, info),
  };
}

String _dailyStatsText(
  AppLocalizations l10n,
  DailyStatsRead stats,
  SpokenAmountFormatter amounts,
) {
  final String currency = l10n.voiceCurrency;
  if (stats.salesCount == 0) {
    return "Aucune vente enregistrée aujourd'hui.";
  }
  final String countStr = stats.salesCount == 1
      ? '1 vente'
      : '${stats.salesCount} ventes';
  final String revStr = '${amounts(stats.totalRevenue)} $currency';
  final String profStr = '${amounts(stats.totalProfit)} $currency';
  return "Aujourd'hui : $countStr, total $revStr, bénéfice $profStr.";
}

String _lowStockText(
  AppLocalizations l10n,
  LowStockRead lowStock,
  SpokenAmountFormatter amounts,
) {
  if (lowStock.products.isEmpty) {
    return 'Aucun produit en rupture ou stock bas.';
  }
  final int count = lowStock.products.length;
  final String header = count == 1
      ? '1 produit en alerte de stock'
      : '$count produits en alerte de stock';
  final String details = lowStock.products
      .map((p) => '${p.name} (reste ${_quantity(p.stock, amounts)})')
      .join(', ');
  return '$header : $details.';
}

String _productPriceText(
  AppLocalizations l10n,
  ProductPriceRead price,
  SpokenAmountFormatter amounts,
) {
  final String currency = l10n.voiceCurrency;
  final String base =
      'Le prix de ${price.product} est de ${amounts(price.price)} $currency';
  if (price.purchasePrice != null && price.purchasePrice! > 0) {
    return '$base (prix d\'achat : ${amounts(price.purchasePrice!)} $currency).';
  }
  return '$base.';
}

String _stockOutText(
  AppLocalizations l10n,
  StockOutRecorded stockOut,
  SpokenAmountFormatter amounts,
) {
  final String qtyStr = _quantity(stockOut.qty, amounts);
  final String remainingStr = _quantity(stockOut.resultingStock, amounts);
  return 'Sortie de $qtyStr ${stockOut.product} (${stockOut.reason}) enregistrée. Stock restant : $remainingStr.';
}

String _pageNavigatedText(AppLocalizations l10n, PageNavigated nav) {
  return 'Navigation vers ${nav.label}.';
}

String _reportExportedText(AppLocalizations l10n, ReportExported report) {
  final String countStr = report.salesCount == 1
      ? '1 vente'
      : '${report.salesCount} ventes';
  return 'Rapport des ventes ($countStr) généré et partagé au format ${report.format.toUpperCase()}.';
}

String _productCreatedText(
  AppLocalizations l10n,
  ProductCreated created,
  SpokenAmountFormatter amounts,
) {
  final String currency = l10n.voiceCurrency;
  final String priceStr = '${amounts(created.price)} $currency';
  final String qtyStr = _quantity(created.initialQuantity, amounts);
  return 'Produit ${created.name} créé à $priceStr avec un stock initial de $qtyStr.';
}

String _productPriceUpdatedText(
  AppLocalizations l10n,
  ProductPriceUpdated updated,
  SpokenAmountFormatter amounts,
) {
  final String currency = l10n.voiceCurrency;
  final String newPriceStr = '${amounts(updated.newPrice)} $currency';
  final String oldPriceStr = '${amounts(updated.oldPrice)} $currency';
  return 'Le prix de ${updated.product} a été mis à jour à $newPriceStr (ancien prix : $oldPriceStr).';
}

String _salesHistoryText(
  AppLocalizations l10n,
  SalesHistoryRead history,
  SpokenAmountFormatter amounts,
) {
  final String currency = l10n.voiceCurrency;
  if (history.sales.isEmpty) {
    return 'Aucune vente récente trouvée.';
  }
  final int count = history.sales.length;
  final String header = count == 1 ? 'Dernière vente' : 'Dernières ventes';
  final String details = history.sales
      .map((s) {
        final String itemsStr = s.itemsCount == 1
            ? '1 article'
            : '${s.itemsCount} articles';
        return '$itemsStr pour ${amounts(s.total)} $currency';
      })
      .join(', ');
  return '$header : $details.';
}

String _businessInfoText(AppLocalizations l10n, BusinessInfoRead info) {
  final String prodStr = info.activeProductsCount == 1
      ? '1 produit actif'
      : '${info.activeProductsCount} produits actifs';
  final String salesStr = info.totalSalesCount == 1
      ? '1 vente'
      : '${info.totalSalesCount} ventes';
  return '${info.storeName} : $prodStr, $salesStr enregistrées.';
}

/// A sale, its lines and its total in words.
String _withTotal(
  AppLocalizations l10n,
  String body,
  SpokenAmountFormatter amounts,
  double total,
) {
  return '$body - ${l10n.voiceTotal('${amounts(total)} ${l10n.voiceCurrency}')}';
}

/// The lines of a recap, one after the other.
String _lines(
  AppLocalizations l10n,
  List<VoiceRecapLine> lines,
  SpokenAmountFormatter amounts,
) {
  return lines
      .map((VoiceRecapLine line) => _line(l10n, line, amounts))
      .join(', ');
}

/// One line, said with its unit when the use case reported one.
///
/// The contract of a restock carries no unit, and this says the quantity and the
/// name rather than guessing a unit the shop may not use.
String _line(
  AppLocalizations l10n,
  VoiceRecapLine line,
  SpokenAmountFormatter amounts,
) {
  final String? unit = line.unit;
  if (unit == null) {
    return l10n.voiceRecapLinePlain(_quantity(line.qty, amounts), line.name);
  }
  return l10n.voiceRecapLine(
    _qtyWithUnit(l10n, line.qty, unit, amounts),
    line.name,
  );
}

/// A quantity, in words when it is a whole number.
///
/// "Deux" is understood and "12,5" is not read as a decimal by a synthesiser, so a
/// whole number is turned into words and anything else keeps its digits rather than
/// being rounded away from what the merchant said.
String _quantity(double qty, SpokenAmountFormatter amounts) {
  return qty == qty.roundToDouble() ? amounts(qty) : _digits(qty);
}

/// A quantity as it is written, with the comma French uses and no trailing zero.
///
/// "1,50 kg" is read by a synthesiser as "un virgule cinq zéro" or "un virgule cinq"
/// depending on the synthesiser, and neither is the number the merchant said.
String _digits(double qty) {
  if (qty == qty.roundToDouble()) {
    return qty.toStringAsFixed(0).replaceAll('.', ',');
  }
  return qty
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceAll('.', ',');
}

/// The quantity and its unit as the phrase a recap line and a stock answer start
/// with.
///
/// The article is the part a plural rule cannot supply: it belongs to the gender of
/// the unit and not to the quantity, so "une pièce" and "un kilogramme" are both
/// correct French and only one of them is correct per product. It is said when there
/// is exactly one unit, and dropped otherwise, which is why "deux pièces" has no "un"
/// in front of it and "une pièce" does.
///
/// The unit word itself is left to the plural rules of the locale, which is why
/// [kFeminineUnits] lists only the two codes of the catalog that are feminine and
/// every other code falls back to the piece: a recap that says "piece" where the shop
/// says "lot" is a word wrong, and a recap that leaves the unit out is a sentence
/// broken.
String _qtyWithUnit(
  AppLocalizations l10n,
  double qty,
  String code,
  SpokenAmountFormatter amounts,
) {
  final String canonical = _canonicalUnit(code);
  final String unit = switch (canonical) {
    'KG' => l10n.voiceUnitKg(qty.round()),
    'LITRE' => l10n.voiceUnitLitre(qty.round()),
    'SACHET' => l10n.voiceUnitSachet(qty.round()),
    'SAC' => l10n.voiceUnitSac(qty.round()),
    'BOITE' => l10n.voiceUnitBoite(qty.round()),
    _ => l10n.voiceUnitPiece(qty.round()),
  };
  if (qty != 1) {
    return '${_quantity(qty, amounts)} $unit';
  }
  return kFeminineUnits.contains(canonical)
      ? l10n.voiceQtyOneFeminine(unit)
      : l10n.voiceQtyOne(unit);
}

/// The unit code to say, which is the code the catalog stores or the piece.
///
/// The fallback is resolved before the article is chosen, because an unknown code
/// becomes a piece and "pièce" is feminine: deciding the article from the unknown
/// code would say "un pièce" for a product sold by the lot.
String _canonicalUnit(String code) {
  return switch (code.toUpperCase()) {
    'KG' || 'LITRE' || 'SACHET' || 'SAC' || 'BOITE' => code.toUpperCase(),
    _ => 'PIECE',
  };
}

/// The unit codes of the catalog whose French noun is feminine.
const Set<String> kFeminineUnits = <String>{'PIECE', 'BOITE'};
