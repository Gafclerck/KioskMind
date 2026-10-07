import '../models/export_file.dart';

/// Partage un fichier généré avec le système (feuille de partage native).
abstract interface class ShareExportGateway {
  Future<void> share(ExportFile file);
}
