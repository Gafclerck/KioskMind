import 'dart:io';

// Checks the local `.env` file before a build that injects it with
// `--dart-define-from-file=.env`.
//
// Usage:
//   dart run tool/check_env.dart             # checks .env against .env.example
//   dart run tool/check_env.dart path/to/env # checks another file
//
// Exits with 1 when the file cannot be used as-is, so the reason never shows
// up later as a raw provider error on the device.

const String _placeholderPrefix = 'votre_';

final RegExp _property = RegExp(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)?$');

Map<String, String> _readProperties(File file) {
  final Map<String, String> properties = <String, String>{};
  for (final String rawLine in file.readAsLinesSync()) {
    final String line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final RegExpMatch? match = _property.firstMatch(line);
    if (match == null) {
      throw FormatException('ligne invalide : $rawLine');
    }
    properties[match.group(1)!] = (match.group(2) ?? '').trim();
  }
  return properties;
}

/// `dart run` ignore la valeur de retour de `main` : le code de sortie vient de
/// [exitCode], qu'on positionne avant de rendre la main.
void main(List<String> arguments) {
  exitCode = _run(arguments);
}

int _run(List<String> arguments) {
  final File envFile = File(arguments.isEmpty ? '.env' : arguments.first);
  final File exampleFile = File('.env.example');

  if (!envFile.existsSync()) {
    stderr.writeln(
      '${envFile.path} est introuvable.\n'
      'Creez-le a partir du template : cp .env.example .env',
    );
    return 1;
  }

  if (!exampleFile.existsSync()) {
    stderr.writeln('.env.example est introuvable, rien a comparer.');
    return 1;
  }

  final Map<String, String> env;
  final Map<String, String> example;
  try {
    env = _readProperties(envFile);
    example = _readProperties(exampleFile);
  } on FormatException catch (error) {
    stderr.writeln('${envFile.path} : ${error.message}');
    return 1;
  }

  final List<String> problems = <String>[];

  for (final MapEntry<String, String> entry in env.entries) {
    final String value = entry.value;
    if (value.toLowerCase().startsWith(_placeholderPrefix)) {
      problems.add('${entry.key} est encore un placeholder ($value).');
    }
  }

  for (final String key in example.keys) {
    if (!env.containsKey(key)) {
      problems.add('$key manque dans ${envFile.path}.');
    }
  }

  for (final String key in env.keys) {
    if (!example.containsKey(key)) {
      problems.add('$key est dans ${envFile.path} mais pas dans .env.example.');
    }
  }

  final List<String> withValues = <String>[
    for (final MapEntry<String, String> entry in env.entries)
      if (entry.value.isNotEmpty) entry.key,
  ];

  if (problems.isEmpty) {
    stdout.writeln(
      '${envFile.path} est exploitable (${withValues.length} valeur(s) renseignee(s)).',
    );
    return 0;
  }

  stderr.writeln('${envFile.path} est incomplet :');
  for (final String problem in problems) {
    stderr.writeln('  - $problem');
  }
  stderr.writeln('Corrigez le fichier puis relancez.');
  return 1;
}
