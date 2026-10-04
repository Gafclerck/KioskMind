import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the dependency rules of the module contract (C3): each layer of the
/// voice feature may import the layers below it and nothing else.
///
/// The rules are only as good as the moment someone is told about them, and a
/// widget quietly importing `data/` compiles exactly as well as a correct one.
/// So the rules are executable, and this file is what makes them so.
void main() {
  final Directory feature = Directory('lib/features/voice_assistant');

  test('the voice feature is where these rules are expected', () {
    expect(
      feature.existsSync(),
      isTrue,
      reason: 'lancer depuis la racine du projet',
    );
  });

  test('presentation does not reach the data layer', () {
    expect(
      _importsIn(
        _layer(feature, 'presentation'),
        forbidden: <String>[r'/data/'],
      ),
      isEmpty,
    );
  });

  test('data does not reach the presentation layer', () {
    expect(
      _importsIn(
        _layer(feature, 'data'),
        forbidden: <String>[r'/presentation/'],
      ),
      isEmpty,
    );
  });

  test('domain stays pure Dart and depends on no other layer', () {
    expect(
      _importsIn(
        _layer(feature, 'domain'),
        forbidden: <String>[
          r'/data/',
          r'/presentation/',
          r'/di/',
          r'package:flutter',
          r'package:flutter_riverpod',
          r'package:firebase_',
          r'package:cloud_',
        ],
      ),
      isEmpty,
    );
  });

  test('core does not depend on a feature', () {
    expect(
      _importsIn(
        Directory('lib/core'),
        forbidden: <String>[
          r'package:kiosk_mind/features/',
          r'../../features/',
        ],
      ),
      isEmpty,
    );
  });

  test('the voice feature never names a speech plugin', () {
    expect(
      _importsIn(
        feature,
        forbidden: <String>[r'package:speech_to_text', r'package:flutter_tts'],
      ),
      isEmpty,
      reason:
          'les plugins sont derriere les adaptateurs de core/voice_services',
    );
  });
}

Directory _layer(Directory feature, String name) {
  return Directory('${feature.path}/$name');
}

/// Every import found in [directory] that mentions one of [forbidden].
///
/// A relative import is matched as written, a package import as written too, so
/// the rule follows the file rather than the way the author spelled the path.
List<String> _importsIn(
  Directory directory, {
  required List<String> forbidden,
}) {
  final List<String> violations = <String>[];
  for (final FileSystemEntity entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    for (final Match match in _importPattern.allMatches(
      entity.readAsStringSync(),
    )) {
      final String target = match.group(1)!;
      final bool blocked = forbidden.any(
        (String token) => target.contains(token),
      );
      if (blocked) {
        violations.add('${entity.path} -> $target');
      }
    }
  }
  return violations;
}

/// A re-export moves code between layers just as silently as an import, so both
/// are matched.
final RegExp _importPattern = RegExp(r"(?:import|export)\s+'([^']+)'");
