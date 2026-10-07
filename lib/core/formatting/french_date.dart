/// Formate une date en français court : « 12 octobre 2026 ».
library;

/// Mois en français, indexés sur [DateTime.month] (1-12).
const List<String> _frenchMonths = <String>[
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Rendu lisible d'une date, ou une tiret quand elle est absente.
///
/// Volontairement sans `intl` : ajouter la locale française demanderait un
/// `initializeDateFormatting` au démarrage pour un format unique.
String formatFrenchDate(DateTime? date) {
  if (date == null) {
    return '—';
  }
  final String month = _frenchMonths[date.month - 1];
  return '${date.day} $month ${date.year}';
}
