import 'dart:math' as math;

import '../entities/fact_result.dart';

/// Exception thrown when an AI formulated response violates truthfulness to facts.
final class GuardViolationException implements Exception {
  const GuardViolationException(this.reason);
  final String reason;

  @override
  String toString() => 'GuardViolationException: $reason';
}

/// Anti-hallucination verification port & implementation ported from assistantv3.
///
/// An AI formulated response cannot invent figures (calculations, sums, percentages),
/// omit key facts, or distort entity identifiers.
///
/// The 3 invariant rules:
/// 1. **No invented values**: Any number in the text above [threshold] must originate
///    from the facts. Small integers (< threshold) are permitted for natural speech
///    counters (e.g. "2 articles", "1 vente").
/// 2. **No omitted values**: All significant numbers present in the facts must be
///    faithfully reflected in the generated response.
/// 3. **Preserved identifiers**: Codes (e.g. references, SKU) must not be corrupted.
class FactPreservingGuard {
  const FactPreservingGuard({
    this.threshold = 100.0,
    this.strictOmissionCheck = false,
  });

  /// The materiality threshold below which numbers are tolerated as counters.
  final double threshold;

  /// Whether to strictly require every single number from facts to appear in the reply.
  /// Defaults to false for conversational lightness (allowing e.g. omitting repeated intermediate IDs).
  final bool strictOmissionCheck;

  static final RegExp _thousandsAndDecimals = RegExp(
    r'[0-9][0-9\s  '
    "'"
    r'’.,]*',
  );

  static final RegExp _identifiersPattern = RegExp(
    r'(?<![A-Za-z])[A-Za-z]{2,}[-_][A-Za-z]*\d[A-Za-z0-9_-]*',
  );

  /// Validates [content] against [facts]. Throws [GuardViolationException] if invalid.
  void check(List<FactResult> facts, String content) {
    final Set<num> factsNumbers = <num>{};
    final Set<String> factsIdentifiers = <String>{};

    for (final FactResult fact in facts) {
      factsNumbers.addAll(fact.extractNumbers());
      factsIdentifiers.addAll(fact.extractIdentifiers());
    }

    final Set<num> responseNumbers = extractNumbers(content);
    final Set<String> responseIdentifiers = extractIdentifiers(content);

    // 1. Check for invented numbers beyond materiality threshold
    final List<num> invented = <num>[];
    for (final num n in responseNumbers) {
      if (!_containsFuzzy(factsNumbers, n) && n >= threshold) {
        invented.add(n);
      }
    }
    if (invented.isNotEmpty) {
      throw GuardViolationException(
        'La réponse contient des valeurs absentes des faits réels: $invented',
      );
    }

    // 2. Check for omitted numbers (if strict omission is enabled)
    if (strictOmissionCheck) {
      final List<num> missing = <num>[];
      for (final num n in factsNumbers) {
        if (!_containsFuzzy(responseNumbers, n) && n >= threshold) {
          missing.add(n);
        }
      }
      if (missing.isNotEmpty) {
        throw GuardViolationException(
          'La réponse omet des valeurs présentes dans les faits: $missing',
        );
      }
    }

    // 3. Check for altered identifiers (one-way: facts -> response)
    final List<String> altered = <String>[];
    for (final String id in factsIdentifiers) {
      if (!responseIdentifiers.contains(id)) {
        altered.add(id);
      }
    }
    if (altered.isNotEmpty && factsIdentifiers.isNotEmpty) {
      // Only raise if the fact had explicit identifiers that vanished completely
      // from the response words.
      final String normalizedContent = content.toLowerCase();
      for (final String id in altered) {
        final String cleanId = id.replaceAll(RegExp(r'[-_]'), '');
        if (!normalizedContent.contains(id) &&
            !normalizedContent.contains(cleanId)) {
          throw GuardViolationException(
            'La réponse ne restitue pas les identifiants requis: $altered',
          );
        }
      }
    }
  }

  /// Extracts and normalizes all numbers found in [text].
  Set<num> extractNumbers(String text) {
    final Set<num> result = <num>{};
    for (final RegExpMatch match in _thousandsAndDecimals.allMatches(text)) {
      final num? normalized = normalizeNumber(match.group(0)!);
      if (normalized != null) {
        result.add(normalized);
      }
    }
    return result;
  }

  /// Extracts identifiers matching reference formats.
  Set<String> extractIdentifiers(String text) {
    final Set<String> result = <String>{};
    for (final RegExpMatch match in _identifiersPattern.allMatches(text)) {
      final String id = match
          .group(0)!
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
      result.add(id);
    }
    return result;
  }

  /// Normalizes written numbers in francophone conventions.
  /// Handles "40 000", "40.000", "40,000", "12,5", "1 234,56".
  num? normalizeNumber(String raw) {
    String tokens = raw.trim();
    if (tokens.isEmpty) return null;

    // Check last separator
    final int lastDot = tokens.lastIndexOf('.');
    final int lastComma = tokens.lastIndexOf(',');
    final int lastSep = math.max(lastDot, lastComma);

    if (lastSep >= 0) {
      final String afterSep = tokens.substring(lastSep + 1);
      // If 1 or 2 digits after the last comma/dot, it is usually a decimal part
      if ((afterSep.length == 1 || afterSep.length == 2) &&
          _isDigits(afterSep)) {
        final String beforeSep = tokens
            .substring(0, lastSep)
            .replaceAll(RegExp(r"[\s  '’.,]"), '');
        final String cleanNumber =
            '${beforeSep.isEmpty ? "0" : beforeSep}.$afterSep';
        return num.tryParse(cleanNumber);
      }
      // If exactly 3 digits after the separator, it's a thousands separator in French/continental notation
      if (afterSep.length == 3 && _isDigits(afterSep)) {
        final String cleanNumber = tokens.replaceAll(RegExp(r"[\s  '’.,]"), '');
        return num.tryParse(cleanNumber);
      }
      // Otherwise remove separators
      final String cleanNumber = tokens.replaceAll(RegExp(r"[\s  '’.,]"), '');
      return num.tryParse(cleanNumber);
    }

    final String cleanNumber = tokens.replaceAll(RegExp(r"[\s  '’]"), '');
    return num.tryParse(cleanNumber);
  }

  static bool _isDigits(String s) => RegExp(r'^\d+$').hasMatch(s);

  static bool _containsFuzzy(Set<num> set, num value) {
    for (final num existing in set) {
      if ((existing - value).abs() < 0.001) {
        return true;
      }
    }
    return false;
  }
}
