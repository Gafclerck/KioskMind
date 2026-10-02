import '../../domain/entities/product_snapshot.dart';
import '../../domain/ports/spoken_product_resolver.dart';
import '../../domain/services/text_normalizer.dart';
import '../catalog/product_resolver.dart';

/// Resolves a spoken name with the very machinery an utterance goes through.
///
/// The point is not to have a second resolver: it is to have none. An answer
/// reaches the catalog exactly as a word inside an utterance reaches it, through the
/// same normaliser and the same longest-match resolution, so an answer cannot be
/// understood in a way an utterance would not be.
final class ProductNameResolver implements SpokenProductResolver {
  const ProductNameResolver({required this.resolver, required this.normalizer});

  final ProductResolver resolver;
  final TextNormalizer normalizer;

  @override
  ProductSnapshot? resolve(String spokenName) {
    final NormalizedText normalized = normalizer.normalize(spokenName);
    if (normalized.isEmpty) {
      return null;
    }
    return resolver.matchAt(normalized.tokens, 0)?.resolution.product;
  }
}
