import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';

import '../../tool/sync_intent_catalog.dart';

/// The app and the Cloud Function must offer the same commands. The copy is a
/// byte copy, and this is what makes it one: the day someone edits the copy
/// instead of the source, the test says so.
void main() {
  test('the copy read by the function is identical to the source of truth', () {
    final SyncResult result = syncIntentCatalog(checkOnly: true);

    expect(
      result.message,
      'Copie identique a la source de verite',
      reason: 'lancez: dart run tool/sync_intent_catalog.dart',
    );
  });

  test('both copies are the same file content, down to the byte', () {
    final String source = File(sourcePath).readAsStringSync();
    final String target = File(targetPath).readAsStringSync();

    expect(target, source);
  });

  test('both copies pass the same validation', () {
    final String source = File(sourcePath).readAsStringSync();
    final String target = File(targetPath).readAsStringSync();

    expect(parseIntentCatalog(target).ids, parseIntentCatalog(source).ids);
  });

  test('the tool refuses to leave a stale copy behind', () {
    final File target = File(targetPath);
    final String backup = target.readAsStringSync();
    addTearDown(() => target.writeAsStringSync(backup));

    target.writeAsStringSync('$backup\n');

    expect(syncIntentCatalog(checkOnly: true).message, contains('perimee'));
  });

  test('the tool names the path it reads and the path it writes', () {
    expect(sourcePath, 'voice/intent_catalog.json');
    expect(targetPath, 'functions/voice/intent_catalog.json');
    expect(intentCatalogAsset, sourcePath);
  });
}
