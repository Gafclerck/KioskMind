import 'package:flutter_test/flutter_test.dart';

import '../../tool/routing_cases.dart';
import '../../tool/routing_harness.dart';
import '../../tool/routing_metrics.dart';

/// La porte de non-regression de l'audio C-04: les trois mesures existent, et
/// aucune ne recule.
///
/// `voice_eval` imprime les memes chiffres avec le meme code, donc la sortie de
/// l'outil et cette porte ne peuvent pas dire deux choses differentes. La
/// latence est mesuree et comparee a titre d'information seulement: elle depend
/// de la machine, donc en faire un seuil rendrait le test faux partout sauf sur
/// celle qui l'a ecrit.
void main() {
  const String baselinePath = 'voice/baseline.json';

  final RoutingBaseline baseline = loadBaseline(baselinePath);

  group('la base de reference', () {
    test('couvre les deux jeux mesures', () {
      expect(
        baseline.sets.keys,
        containsAll(<String>[textSetLabel, referenceSetLabel]),
      );
    });

    test('les quatre cases couvrent chaque jeu en entier', () {
      final int bucketed = baseline.sets.values.fold(
        0,
        (int sum, RoutingSetBaseline set_) => sum + set_.bucketed,
      );
      final int total = baseline.sets.values.fold(
        0,
        (int sum, RoutingSetBaseline set_) => sum + set_.total,
      );

      expect(total, greaterThan(0));
      expect(
        bucketed,
        total,
        reason: 'aucun cas ne doit disparaitre entre les quatre cases',
      );
    });

    test('chaque jeu se nomme lui-meme dans la sortie', () {
      expect(baseline.sets[textSetLabel]!.label, 'texte');
      expect(
        baseline.sets[referenceSetLabel]!.label,
        'transcription de reference',
      );
    });
  });

  group('le jeu texte', () {
    late RoutingScore score;

    setUpAll(() async {
      score = await scoreSet(
        label: textSetLabel,
        cases: loadFrozenCases(textSetPath),
        harness: RoutingHarness(),
      );
    });

    test('aucune des mesures ne recule', () {
      final RoutingSetBaseline floor = baseline.sets[textSetLabel]!;
      final String report =
          'mesure : ${score.summary}\nplancher : ${floor.summary}';

      expect(score.wrongExecuted, lessThanOrEqualTo(floor.wrongExecuted));
      expect(score.wrongStopped, lessThanOrEqualTo(floor.wrongStopped));
      expect(score.exactExecuted, greaterThanOrEqualTo(floor.exactExecuted));
      expect(
        score.exactStopped,
        greaterThanOrEqualTo(floor.exactStopped),
        reason: report,
      );
    });

    test('les mauvais routages executes sont les memes cas, pas d autres', () {
      // Un plancher sur le compte seul laisserait passer une permutation: un cas
      // corrige et un autre casse. Les identites sont donc comparees une a une.
      expect(
        score.wrongExecutedIds,
        baseline.sets[textSetLabel]!.wrongExecutedIds,
      );
    });
  });

  group('la transcription de reference', () {
    late RoutingScore score;

    setUpAll(() async {
      score = await scoreSet(
        label: referenceSetLabel,
        cases: loadFrozenCases(referenceSetPath),
        harness: RoutingHarness(),
      );
    });

    test('aucune des mesures ne recule', () {
      final RoutingSetBaseline floor = baseline.sets[referenceSetLabel]!;
      final String report =
          'mesure : ${score.summary}\nplancher : ${floor.summary}';

      expect(score.wrongExecuted, lessThanOrEqualTo(floor.wrongExecuted));
      expect(score.wrongStopped, lessThanOrEqualTo(floor.wrongStopped));
      expect(score.exactExecuted, greaterThanOrEqualTo(floor.exactExecuted));
      expect(
        score.exactStopped,
        greaterThanOrEqualTo(floor.exactStopped),
        reason: report,
      );
    });

    test('les mauvais routages executes sont les memes cas, pas d autres', () {
      expect(
        score.wrongExecutedIds,
        baseline.sets[referenceSetLabel]!.wrongExecutedIds,
      );
    });
  });
}
