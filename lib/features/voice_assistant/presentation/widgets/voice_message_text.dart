import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/voice_services/speech_service_error.dart';
import '../../domain/entities/clarification_slot.dart';
import '../../domain/services/spoken_amount_formatter.dart';
import '../state/voice_message.dart';
import '../state/voice_outcome.dart';

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
  };
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
