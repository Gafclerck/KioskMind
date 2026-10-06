/// Formate un écart de temps en français relatif : « à l'instant »,
/// « il y a 5 min », « il y a 3 h », « il y a 2 j », « il y a 2 mois ».
///
/// Volontairement sans `intl` : la même raison que [formatFrenchDate].
library;

String formatRelativeTime(DateTime date, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now();
  final Duration ecart = reference.difference(date);

  // Une date future (horloge serveur vs locale) se lit « à l'instant ».
  if (ecart.isNegative || ecart.inSeconds < 60) {
    return "à l'instant";
  }
  if (ecart.inMinutes < 60) {
    final int minutes = ecart.inMinutes;
    return 'il y a $minutes min';
  }
  if (ecart.inHours < 24) {
    final int heures = ecart.inHours;
    return 'il y a $heures h';
  }
  final int jours = ecart.inDays;
  if (jours < 30) {
    return 'il y a $jours j';
  }
  final int mois = jours ~/ 30;
  return 'il y a $mois mois';
}
