import '../../domain/entities/product_snapshot.dart';
import '../../domain/entities/voice_config.dart';
import '../../domain/services/text_normalizer.dart';
import '../../domain/services/word_similarity.dart';

/// Outcome of matching the words that were said against the catalog.
enum ResolutionStatus {
  /// One product, active.
  resolved,

  /// Several products fit equally well.
  ambiguous,

  /// The only products that fit are archived, so they are out of the spoken
  /// vocabulary and the command is refused rather than repaired.
  archived,

  /// Nothing in the catalog resembles the words.
  unknown,
}

/// A product the words could denote, with how well it fits.
final class ProductCandidate {
  const ProductCandidate({required this.product, required this.score});

  final ProductSnapshot product;

  /// 1 for an exact alias, less for a misspelling.
  final double score;

  @override
  String toString() => 'ProductCandidate(${product.id}, $score)';
}

/// What the resolver concluded about one spoken name.
final class ProductResolution {
  const ProductResolution({
    required this.status,
    this.candidates = const <ProductCandidate>[],
  });

  ProductResolution.resolved(ProductCandidate candidate)
    : this(
        status: ResolutionStatus.resolved,
        candidates: <ProductCandidate>[candidate],
      );

  ProductResolution.ambiguous(List<ProductCandidate> candidates)
    : this(status: ResolutionStatus.ambiguous, candidates: candidates);

  ProductResolution.archived(List<ProductCandidate> candidates)
    : this(status: ResolutionStatus.archived, candidates: candidates);

  ProductResolution.unknown()
    : this(
        status: ResolutionStatus.unknown,
        candidates: const <ProductCandidate>[],
      );

  final ResolutionStatus status;

  /// Candidates from the best fit down. Never empty except when unknown.
  final List<ProductCandidate> candidates;

  /// The product when there is exactly one usable answer.
  ProductSnapshot? get product => switch (status) {
    ResolutionStatus.resolved => candidates.first.product,
    ResolutionStatus.ambiguous => null,
    ResolutionStatus.archived || ResolutionStatus.unknown => null,
  };

  /// The products a clarification may offer, without duplicates.
  List<ProductSnapshot> get products => <ProductSnapshot>[
    for (final ProductCandidate candidate in candidates) candidate.product,
  ];
}

/// Where a spoken name was found in a token list.
final class ProductSpan {
  const ProductSpan({
    required this.start,
    required this.length,
    required this.resolution,
  });

  final int start;

  /// Number of tokens the name spans.
  final int length;

  final ProductResolution resolution;

  @override
  String toString() => 'ProductSpan($start+$length, ${resolution.status.name})';
}

/// Turns spoken words into a product identifier.
///
/// Resolution is deterministic and never invents a product: the application
/// decides, so an identifier can only come from the catalog. Two cases are
/// deliberately kept apart, because collapsing them would either execute a sale
/// nobody asked for or ask a question the merchant already answered. A name
/// matching several products is reported as ambiguous rather than resolved to
/// the first one.
final class ProductResolver {
  ProductResolver({
    required List<ProductSnapshot> products,
    required this.config,
    required TextNormalizer normalizer,
  }) : _entries = _buildIndex(products, normalizer);

  /// The only source of the thresholds that decide what counts as a name.
  final VoiceConfig config;

  /// Every spoken form a product answers to, longest first.
  final List<_AliasEntry> _entries;

  int get _maxAliasLength => _entries.fold<int>(
    1,
    (int longest, _AliasEntry entry) =>
        entry.tokens.length > longest ? entry.tokens.length : longest,
  );

  /// The name starting at [start], or null when nothing there looks like a
  /// product.
  ///
  /// The longest match wins, so "savon de menage" is preferred over "savon" and
  /// a shorter name never shadows a more specific one.
  ProductSpan? matchAt(List<String> tokens, int start) {
    final int available = tokens.length - start;
    if (available <= 0) {
      return null;
    }
    final int limit = available < _maxAliasLength ? available : _maxAliasLength;
    for (int length = limit; length >= 1; length--) {
      final List<String> span = tokens.sublist(start, start + length);
      final ProductResolution? exact = _exact(span);
      if (exact != null) {
        return ProductSpan(start: start, length: length, resolution: exact);
      }
    }
    return _fuzzy(tokens, start, limit);
  }

  /// Spellings a spoken name can stand for, when the shop says the name alone is
  /// not enough to choose a product.
  List<String> _underSpecifiedForms(String joined) {
    return config.underSpecifiedNames[joined] ?? const <String>[];
  }

  /// Exact alias, singular of the spoken name, then the under-specified names the
  /// shop has declared.
  ///
  /// French pluralises the head of the name and not the whole phrase, so "laits
  /// en poudre" has to reach the catalog's "lait en poudre" without the catalog
  /// having to list every plural a merchant can say.
  ProductResolution? _exact(List<String> span) {
    final String joined = span.join(' ');
    final List<String> forms = <String>[
      joined,
      ..._pluralHeads(joined),
      ..._underSpecifiedForms(joined),
    ];
    final Map<String, List<ProductCandidate>> byId =
        <String, List<ProductCandidate>>{};

    for (final String form in forms) {
      for (final _AliasEntry entry in _entries) {
        if (entry.joined == form) {
          byId.putIfAbsent(
            entry.product.id,
            () => <ProductCandidate>[
              ProductCandidate(product: entry.product, score: 1),
            ],
          );
        }
      }
    }
    return _conclude(byId);
  }

  /// The same name with one noun in the singular, in the order French pluralises
  /// it.
  ///
  /// The plural lands wherever the merchant put it, not necessarily on the last
  /// word: "laits en poudre" pluralises the milk and "riz parfumes" the rice, so
  /// each position in turn is tried on its own rather than as a combination.
  List<String> _pluralHeads(String joined) {
    final List<String> parts = joined.split(' ');
    final List<String> variants = <String>[];
    for (int index = 0; index < parts.length; index++) {
      for (final String form in WordSimilarity.nounForms(parts[index])) {
        if (form == parts[index]) {
          continue;
        }
        variants.add(
          <String>[
            ...parts.sublist(0, index),
            form,
            ...parts.sublist(index + 1),
          ].join(' '),
        );
      }
    }
    return variants;
  }

  /// A misspelling of a one-word product, as a recognizer produces.
  ProductSpan? _fuzzy(List<String> tokens, int start, int limit) {
    for (int length = 1; length <= limit && length <= 2; length++) {
      final List<String> span = tokens.sublist(start, start + length);
      if (span.length != 1) {
        continue;
      }
      final Map<String, List<ProductCandidate>> byId =
          <String, List<ProductCandidate>>{};
      final String spoken = span.first;
      for (final String form in WordSimilarity.nounForms(spoken)) {
        for (final _AliasEntry entry in _entries) {
          if (entry.tokens.length != 1) {
            continue;
          }
          final double score = WordSimilarity.of(form, entry.tokens.first);
          if (score < config.fuzzyThreshold) {
            continue;
          }
          byId
              .putIfAbsent(entry.product.id, () => <ProductCandidate>[])
              .add(ProductCandidate(product: entry.product, score: score));
        }
      }
      final ProductResolution? resolution = _conclude(byId);
      if (resolution != null && resolution.status != ResolutionStatus.unknown) {
        return ProductSpan(
          start: start,
          length: length,
          resolution: resolution,
        );
      }
    }
    return null;
  }

  /// Sorts the candidates per product, then decides whether the best fit stands
  /// alone or ties with another one.
  ///
  /// An archived product drops out as soon as an active one answers, because an
  /// archived name is out of the spoken vocabulary: it must not turn "lait
  /// concentre" into a tie with the "lait" the shop still sells. It only decides
  /// on its own when nothing else fits, which is what refuses the sale of a
  /// discontinued product instead of selling the one that replaced it.
  ProductResolution? _conclude(Map<String, List<ProductCandidate>> byId) {
    final Map<String, List<ProductCandidate>> usable = _withoutArchived(byId);
    if (usable.isEmpty) {
      return null;
    }
    final List<ProductCandidate> candidates =
        <ProductCandidate>[
          for (final List<ProductCandidate> scored in usable.values)
            ProductCandidate(
              product: scored.first.product,
              score: scored
                  .map((ProductCandidate c) => c.score)
                  .reduce((double a, double b) => a > b ? a : b),
            ),
        ]..sort((ProductCandidate a, ProductCandidate b) {
          final int byScore = b.score.compareTo(a.score);
          return byScore != 0 ? byScore : a.product.id.compareTo(b.product.id);
        });

    final ProductCandidate best = candidates.first;
    final bool ties =
        candidates.length > 1 &&
        best.score - candidates[1].score < config.ambiguityMargin;
    if (ties) {
      return ProductResolution.ambiguous(candidates);
    }
    if (best.product.isArchived) {
      return ProductResolution.archived(candidates);
    }
    return ProductResolution.resolved(best);
  }

  static Map<String, List<ProductCandidate>> _withoutArchived(
    Map<String, List<ProductCandidate>> byId,
  ) {
    final bool anyActive = byId.values.any(
      (List<ProductCandidate> scored) => !scored.first.product.isArchived,
    );
    if (!anyActive) {
      return byId;
    }
    return <String, List<ProductCandidate>>{
      for (final MapEntry<String, List<ProductCandidate>> entry in byId.entries)
        if (!entry.value.first.product.isArchived) entry.key: entry.value,
    };
  }

  /// Indexes every spoken name, through the same normalization the transcript
  /// went through, so an alias and an utterance are directly comparable.
  static List<_AliasEntry> _buildIndex(
    List<ProductSnapshot> products,
    TextNormalizer normalizer,
  ) {
    final List<_AliasEntry> entries = <_AliasEntry>[];
    for (final ProductSnapshot product in products) {
      for (final String raw in <String>[product.name, ...product.aliases]) {
        final String joined = normalizer.normalize(raw).text;
        if (joined.isEmpty) {
          continue;
        }
        entries.add(_AliasEntry(product: product, joined: joined));
      }
    }
    entries.sort((_AliasEntry a, _AliasEntry b) {
      final int byLength = b.tokens.length.compareTo(a.tokens.length);
      return byLength != 0 ? byLength : a.joined.compareTo(b.joined);
    });
    return entries;
  }
}

/// One product under one of its spoken names.
final class _AliasEntry {
  _AliasEntry({required this.product, required this.joined});

  final ProductSnapshot product;

  /// The normalized name, as a space-separated token string.
  final String joined;

  List<String> get tokens => joined.split(' ');
}
