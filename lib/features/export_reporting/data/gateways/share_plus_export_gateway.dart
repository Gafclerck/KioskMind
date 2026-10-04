import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/export_file.dart';
import '../../domain/services/share_export_gateway.dart';

class SharePlusExportGateway implements ShareExportGateway {
  const SharePlusExportGateway();

  @override
  Future<void> share(ExportFile file) async {
    final Directory dir = await getTemporaryDirectory();
    final String path = '${dir.path}/${file.filename}';
    final XFile xfile = XFile(path, mimeType: file.mimeType);
    final File target = File(path);
    if (!await target.exists()) {
      await target.writeAsBytes(file.bytes, flush: true);
    }
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[xfile], subject: 'Export KioskMind'),
    );
  }
}
