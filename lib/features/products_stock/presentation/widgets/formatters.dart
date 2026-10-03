/// Formatage partagé des montants en FCFA avec séparateurs de milliers.
///
/// Le design affiche « 2,500 FCFA » et « +700 FCFA », pas « 2500 ».
String formatCfa(int amount, {String suffix = 'FCFA'}) =>
    '${formatThousands(amount)} $suffix';

String formatThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Singulier ou pluriel de l'unité d'un produit : « 12 bouteille », « 3 sacs ».
String formatUnit(int quantity, String unit) {
  final normalized = unit.toLowerCase();
  if (quantity > 1) {
    return normalized.endsWith('s') ? normalized : '${normalized}s';
  }
  if (normalized.endsWith('s')) {
    return normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}
