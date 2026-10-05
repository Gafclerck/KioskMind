export '../../../../core/formatting/money.dart';

/// Singulier ou pluriel de l'unité d'un produit : « 12 bouteille », « 3 sacs ».
///
/// L'unité est déjà au singulier dans le catalogue ; c'est le nombre qui décide, et
/// un accord sur « sac » donnerait « sass ».
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