import '../entities/product_snapshot.dart';

/// What a spoken product name designates.
///
/// Product resolution scores, aliases and similarity are an infrastructure
/// concern (contract C5 puts `ProductResolver` in `data`), but applying an answer to
/// a proposal is domain logic and needs one name resolved. This port is that single
/// need, narrowed to it, so the domain never reads the catalog itself.
///
/// It returns null rather than a candidate list on purpose. A name the catalog does
/// not designate has no answer: the doubt it was meant to settle stays standing and
/// the merchant is asked again, which is the opposite of a silent guess.
abstract interface class SpokenProductResolver {
  /// The product [spokenName] designates, or null when it designates none.
  ProductSnapshot? resolve(String spokenName);
}
