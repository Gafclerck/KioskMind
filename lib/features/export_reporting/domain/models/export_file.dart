import 'dart:typed_data';

/// Fichier exporté, prêt à être partagé.
class ExportFile {
  const ExportFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}
