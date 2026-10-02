import 'package:flutter_test/flutter_test.dart';
import 'package:stt_tts_spike/src/measurement.dart';

void main() {
  group('une mesure', () {
    test('porte un taux plie et un taux litteral distincts', () {
      const PhraseMeasurement measurement = PhraseMeasurement(
        phraseId: 't001',
        reference: 'vendu 2 lait concentré',
        heard: 'Vendu deux lait concentre',
        latency: Duration(milliseconds: 900),
      );

      // Le nombre et les accents ne sont pas une erreur pour l'application.
      expect(measurement.foldedRate.errors, 0);
      // Le taux litteral, lui, montre a quel point les chaines different.
      expect(measurement.literalRate.errors, greaterThan(0));
    });

    test('signale un echec sans transcription', () {
      const PhraseMeasurement measurement = PhraseMeasurement(
        phraseId: 't002',
        reference: 'vendu deux savon',
        heard: '',
        latency: Duration(milliseconds: 8000),
        failure: 'no_match',
      );

      expect(measurement.failure, 'no_match');
      expect(measurement.foldedRate.errors, 3);
    });

    test('reconstruit une mesure identique depuis le JSON', () {
      const PhraseMeasurement source = PhraseMeasurement(
        phraseId: 't003',
        reference: 'combien de riz',
        heard: 'combien de riz',
        latency: Duration(milliseconds: 1200),
      );

      final PhraseMeasurement rebuilt = PhraseMeasurement.fromJson(
        source.toJson(),
      );

      expect(rebuilt.phraseId, source.phraseId);
      expect(rebuilt.heard, source.heard);
      expect(rebuilt.latency, source.latency);
      expect(rebuilt.failure, isNull);
    });

    test('conserve le detail des erreurs dans le JSON', () {
      const PhraseMeasurement measurement = PhraseMeasurement(
        phraseId: 't004',
        reference: 'vendu un lait',
        heard: 'vendu un',
        latency: Duration(milliseconds: 1100),
      );

      final Map<String, Object?> json = measurement.toJson();

      expect(json['foldedErrors'], 1);
      expect(json['literalErrors'], 1);
      expect(json['referenceWords'], 3);
      expect(json.containsKey('failure'), isFalse);
    });
  });

  group('le resume', () {
    List<PhraseMeasurement> sample() {
      return <PhraseMeasurement>[
        const PhraseMeasurement(
          phraseId: 'a',
          reference: 'vendu un lait',
          heard: 'vendu un lait',
          latency: Duration(milliseconds: 1000),
        ),
        const PhraseMeasurement(
          phraseId: 'b',
          reference: 'vendu deux savon',
          heard: 'vendu deux savon',
          latency: Duration(milliseconds: 2000),
        ),
        const PhraseMeasurement(
          phraseId: 'c',
          reference: 'combien de riz',
          heard: 'combien de riz',
          latency: Duration(milliseconds: 3000),
        ),
        const PhraseMeasurement(
          phraseId: 'd',
          reference: 'un litre de lait',
          heard: '',
          latency: Duration(milliseconds: 4000),
          failure: 'no_match',
        ),
      ];
    }

    test('additionne les erreurs du corpus, sans moyenner les taux', () {
      // Trois phrases correctes et une phrase de quatre mots entierement perdue:
      // le taux du corpus est 4 erreurs sur 13 mots, pas la moyenne de quatre taux
      // qui donnerait 0,25 et semblerait deux fois meilleur.
      final RunSummary summary = RunSummary.from(sample());

      expect(summary.referenceWords, 13);
      expect(summary.errors, 4);
      expect(summary.rate, closeTo(4 / 13, 1e-9));
    });

    test('compte les echecs a part', () {
      final RunSummary summary = RunSummary.from(sample());

      expect(summary.measured, 4);
      expect(summary.failed, 1);
    });

    test('donne la mediane et la p95 sur des latences reelles', () {
      // Rang le plus proche: sur les trente phrases du spike le rang median tombe
      // pile sur la mediane, donc l approximation ne joue pas ici.
      final RunSummary summary = RunSummary.from(sample());

      expect(summary.medianLatency, const Duration(milliseconds: 2000));
      expect(summary.p95Latency, const Duration(milliseconds: 4000));
    });

    test('ne plante pas sur une passe vide', () {
      final RunSummary summary = RunSummary.from(<PhraseMeasurement>[]);

      expect(summary.measured, 0);
      expect(summary.rate, 0);
      expect(summary.medianLatency, Duration.zero);
    });

    test('s arrondit a quatre decimales dans le JSON', () {
      final Map<String, Object?> json = RunSummary.from(sample()).toJson();

      expect(
        json['wordErrorRateFolded'],
        double.parse((4 / 13).toStringAsFixed(4)),
      );
      expect(json['wordErrorRateLiteral'], isA<double>());
      expect(json['medianLatencyMs'], 2000);
      expect(json['p95LatencyMs'], 4000);
    });
  });

  group('la configuration', () {
    test('sait qu elle impose la reconnaissance embarquee', () {
      expect(SpikeConfig.onDevice, isTrue);
    });

    test('enregistre les conditions de la mesure', () {
      final Map<String, Object?> json = const SpikeConfig().toJson();

      expect(json['localeId'], 'fr_FR');
      expect(json['onDevice'], isTrue);
      expect(json['listenForMs'], 8000);
      expect(json['pauseForMs'], 1500);
    });
  });
}
