import 'dart:io';

/// Keeps the copy of the intent catalog the Cloud Function reads identical to
/// the source of truth.
///
/// The catalog drives the rule parser (T1) in the app and the LLM tools (T2) in
/// the function. Two copies is already one too many; two *different* copies is
/// worse than none, because the app would offer a command the function cannot
/// see. So the copy is a byte copy, never edited by hand, and `--check` makes
/// the drift a failure instead of a surprise.
///
/// Usage:
///   dart run tool/sync_intent_catalog.dart           writes the copy
///   dart run tool/sync_intent_catalog.dart --check   fails if it differs
const String sourcePath = 'voice/intent_catalog.json';
const String targetPath = 'functions/voice/intent_catalog.json';

/// Outcome of a sync, reported as text so the tool and the test read the same
/// thing.
final class SyncResult {
  const SyncResult({required this.written, required this.message});

  final bool written;
  final String message;
}

void main(List<String> arguments) {
  final bool checkOnly = arguments.contains('--check');
  final SyncResult result = syncIntentCatalog(checkOnly: checkOnly);
  stdout.writeln(result.message);
  if (!result.written) {
    exitCode = 1;
  }
}

SyncResult syncIntentCatalog({required bool checkOnly}) {
  final File source = File(sourcePath);
  if (!source.existsSync()) {
    throw StateError('Catalogue introuvable: $sourcePath');
  }
  final String content = source.readAsStringSync();
  final File target = File(targetPath);

  if (checkOnly) {
    return _check(target, content);
  }
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(content);
  return SyncResult(written: true, message: 'Ecrit: $targetPath');
}

SyncResult _check(File target, String expected) {
  if (!target.existsSync()) {
    return const SyncResult(
      written: false,
      message: 'Copie absente: lancez la synchronisation sans --check',
    );
  }
  if (target.readAsStringSync() == expected) {
    return const SyncResult(
      written: true,
      message: 'Copie identique a la source de verite',
    );
  }
  return SyncResult(
    written: false,
    message: 'Copie perimee: $targetPath ne correspond pas a $sourcePath',
  );
}
