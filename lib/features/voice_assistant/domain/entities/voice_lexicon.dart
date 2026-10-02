// The words that decide the shape of a spoken command, kept apart from the
// intent catalog on purpose.
///
// The catalog says *which* command an utterance asks for. This file says what the
// surrounding words do to it: refuse it, or make it impossible to execute as it
// stands. They are different concerns, and mixing them would make adding a
// command mean editing a parser.
///
// Every table is read with tokens the normalizer produced: lowercase, without
// accents, with elisions already resolved. A word only counts as itself, never
// as a fragment of another one, so "paquet" is not the "que" of "comme hier".

library;

import 'doubt.dart';

/// Words that ask for something no command may ever do.
///
/// Checked before the intent, because "supprime le produit" names no command and
/// would otherwise be reported as an utterance about something else.
const Set<String> kDestructiveWords = <String>{
  'supprime',
  'supprimes',
  'supprimer',
  'efface',
  'effaces',
  'effacer',
  'archive',
  'archives',
  'archiver',
  'jette',
  'detruis',
  'detruit',
};

/// Words meaning the whole shop rather than one command.
///
/// "annule tout" is not the cancellation of one sale, and treating it as one
/// would invent an amount to give back.
const Set<String> kUnboundedWords = <String>{'tout', 'tous', 'toute', 'toutes'};

/// What follows "tout" when the words point back at a moment already said
/// instead of at everything: "que tout a l'heure".
///
/// The token is "lheure" and not "heure": the normaliser keeps the bare "l'" and
/// joins it to the next word, so the phrase arrives as one token. Measured on the
/// frozen set, not guessed. "lheure" occurs nowhere else in the shop's
/// vocabulary, which is what makes it a reliable marker.
const String kPastReferenceTail = 'lheure';

/// How many tokens may separate "tout" from that tail.
///
/// Two positions, which is what "a l'heure" needs and no more: a reach of three
/// would also read "tout a l' heure" as the whole shop.
const int kPastReferenceReach = 2;

/// An order is a real thing a merchant says, and no use case handles it.
///
/// Reported as its own kind rather than as an unknown utterance, so the answer
/// can say orders are not handled yet instead of asking for a product.
const Set<String> kOrderWords = <String>{'commande', 'commandes', 'commander'};

/// Words that ask for a price instead of recording a movement.
///
/// A price question is a legitimate question, and answering it by recording a
/// sale would be the worst possible answer. A stock question is exempt: asking
/// how much something costs is exactly what a query is for.
const Set<String> kPriceQuestionWords = <String>{'prix', 'coute', 'coutent'};

/// Words that cancel what was just said: "un sucre, non, un riz".
///
/// A merchant corrects himself mid-sentence, and the first reading of it must
/// not be recorded. The cancellation only reaches back to the previous product,
/// never to the rest of the sentence.
const Set<String> kCorrectionWords = <String>{'non', 'pas'};

/// Words that point at something already said, which one utterance cannot
/// resolve: "le meme", "celle-la", "comme hier".
const Set<String> kAnaphoraWords = <String>{
  'meme',
  'comme',
  'celle',
  'celui',
  'ceux',
  'que',
  'ladit',
};

/// Words that place a quantity outside this utterance: yesterday's stock,
/// whatever is missing, the previous pack.
const Set<String> kRelativeQuantityWords = <String>{
  'manque',
  'manquant',
  'manquante',
  'hier',
  'veille',
  'premiere',
  'autre',
  'autres',
  'chaque',
};

/// The word "reste", which means a relative quantity only when a command is
/// being written.
///
/// "combien il reste de riz" is a question with an answer in the catalog, and
/// "vendu le reste de sucre" is not, so the same word cannot carry one meaning
/// for the whole module.
const Set<String> kRestRelativeQuantityWords = <String>{'reste'};

/// Words that may sit between a quantity and the product it counts, and carry no
/// meaning of their own: the partitive article and the "de" of "de l'eau".
const Set<String> kQuantityBridges = <String>{
  'de',
  'du',
  'des',
  'le',
  'la',
  'les',
  'en',
};

/// Units a merchant speaks before the product name.
///
/// They are bridges, not quantities: "cinq sachets de sucre" is five sachets, and
/// a unit alone never says how many. "livre" is here as a bridge even though
/// nothing converts it to the product's own unit, because it must not be read as
/// a quantity of one.
const Set<String> kUnitWords = <String>{
  'sachet',
  'sachets',
  'sac',
  'sacs',
  'carton',
  'cartons',
  'boite',
  'boites',
  'bidon',
  'bidons',
  'bouteille',
  'bouteilles',
  'paquet',
  'paquets',
  'pack',
  'packs',
  'kilo',
  'kilos',
  'kilogramme',
  'kilogrammes',
  'litre',
  'litres',
  'piece',
  'pieces',
  'unite',
  'unites',
  'livre',
  'livres',
};

/// Currency words spoken after an amount.
const Set<String> kCurrencyWords = <String>{
  'franc',
  'francs',
  'fcfa',
  'xof',
  're',
};

/// How many tokens a quantity may reach back over before giving up.
///
/// Bounded on purpose: an unbounded backward search would attribute a number
/// spoken much earlier to whichever product happens to follow it.
const int kQuantityReach = 6;

/// How many tokens may separate an amount from the word that introduces it.
///
/// Small on purpose: a long reach would let "un riz a sept cents le kilo et un
/// sucre" attach the second product's price to the first.
const int kAmountReach = 3;

/// A group of words that raises one doubt when heard on a command.
typedef DoubtMarker = ({DoubtKind kind, Set<String> words});

/// Markers that apply whatever the intent is.
const List<DoubtMarker> kDoubtMarkers = <DoubtMarker>[
  (kind: DoubtKind.anaphora, words: kAnaphoraWords),
  (kind: DoubtKind.undeterminedQuantity, words: kRelativeQuantityWords),
];

/// Markers that only apply while a movement is being written, because the same
/// words mean something else in a question.
const Map<DoubtKind, Set<String>> kWriteOnlyDoubtMarkers =
    <DoubtKind, Set<String>>{
      DoubtKind.undeterminedQuantity: kRestRelativeQuantityWords,
    };
