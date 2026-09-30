/// Canonical form of a value recorded in the call journal.
///
/// Firestore returns every number as a double, so a total computed from XOF
/// amounts can carry binary noise. Rounding to two decimals and turning an
/// integral double into an integer keeps `expected.handlerArgs` in the golden
/// set comparable without a formatting tolerance.
Object? canonicalValue(Object? value) {
  if (value is double) {
    final double rounded = roundAmount(value);
    return rounded == rounded.truncateToDouble() ? rounded.toInt() : rounded;
  }
  if (value is List<Object?>) {
    return <Object?>[for (final Object? item in value) canonicalValue(item)];
  }
  if (value is Map<String, Object?>) {
    return canonicalArguments(value);
  }
  return value;
}

Map<String, Object?> canonicalArguments(Map<String, Object?> arguments) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in arguments.entries)
      entry.key: canonicalValue(entry.value),
  };
}

double roundAmount(double value) => (value * 100).roundToDouble() / 100;
