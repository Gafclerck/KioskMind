/// Formats de sortie supportés par l'export des données.
enum ExportFormat {
  csv,
  pdf;

  String get label => switch (this) {
    ExportFormat.csv => 'CSV',
    ExportFormat.pdf => 'PDF',
  };
}
