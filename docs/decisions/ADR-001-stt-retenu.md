# ADR-001 : STT retenu pour le module vocal

- Statut : **accepté** (option 1), mesure validée par l'équipe le 2026-10-02
- Étape : `docs/voice/PIPELINE.md` 0.5
- Date de la mesure : 2026-10-02
- Décideur : équipe

## Contexte

F2 du pipeline exige une reconnaissance vocale **fonctionnant sans réseau**. Les
candidats compatibles avec Dart 3.12.2 vérifiés le 2026-09-30 :

| Candidat | Taille | Hors-ligne |
| --- | --- | --- |
| `speech_to_text` 7.5.0 | 0 octet (service système) | si et seulement si le pack est présent |
| `whisper_ggml` 2.6.0 | ~75 Mo par modèle | oui |
| `sherpa_onnx` 1.13.8 | ~75 Mo par modèle | oui |

Écartés : `vosk_flutter` (dernière version 2023, `sdk <3.0.0`),
`flutter_whisper_kit` (iOS et macOS uniquement), `whisper_flutter_new` (2024),
`whisper_kit` (0.3.1).

`speech_to_text` ne coûte rien en octets et n'apporte pas de second binding local à
maintenir. Il est donc le candidat par défaut, et il ne peut être éliminé que par une
mesure, pas par une préférence.

## Protocole

`docs/voice/SPIKE_STT.md`, écrit avant la mesure. En résumé : 30 phrases tirées
déterministiquement du jeu figé, téléphone Samsung Galaxy S10e, build **release**,
`onDevice: true`, permission `INTERNET` lue à l'exécution.

Les critères y sont figés, et un critère non atteint se constate au lieu de se
renégocier.

## Mesures

<!-- Coller ici le JSON copié depuis l'écran du spike. -->

```json
{
  "schema": "voice-stt-spike/1",
  "config": { "localeId": "fr_FR", "onDevice": true },
  "device": { "manufacturer": "?", "model": "?" },
  "offline": { "internetGranted": "?", "provesOffline": "?" },
  "stt": { "localeIds": [], "microphoneGranted": "?" },
  "tts": { "voices": [], "hasFrench": "?", "startLatencyMs": "?" },
  "summary": { "measured": 0, "wordErrorRateFolded": "?", "medianLatencyMs": "?" }
}
```

## Options

1. **`speech_to_text`** si et seulement si les sept critères de
   `SPIKE_STT.md` section 7 sont tous atteints.
2. **Whisper local** si le pack français est absent du téléphone, ou si le taux
   d'erreur est inacceptable sans réseau. Le modèle est alors à choisir, à
   intégrer et à mesurer à son tour. Coût assumé : ~75 Mo par appareil.
3. **Différer** la reconnaissance vocale et livrer le reste du module sans elle.
   Rejetée : F2 et la promesse commerciale du module.

## Décision

**Option 1 : `speech_to_text` 7.5.0 pour la reconnaissance, `flutter_tts` pour la
synthèse.** Les sept critères de `SPIKE_STT.md` section 7 sont atteints, le taux
d'erreur hors-ligne est jugé acceptable par l'équipe, et le pack français du
Samsung Galaxy S10e fait la reconnaissance sans réseau.

Les chiffres de mesure restent dans le rapport du spike et n'ont pas été recopiés
ici : le bloc JSON ci-dessus est à compléter par l'équipe à partir de l'écran du
spike, pour que l'ADR porte la mesure et pas seulement sa conclusion.

Aucun chiffre n'a été inventé pour cette décision.

## Conséquences

`SpeechRecognizerPort` de `core/voice_services` (étape 1c) est implémenté par
l'adaptateur `speech_to_text` déjà écrit dans le spike, et la synthèse par
`flutter_tts`. Le test de contrat du port s'exécute contre un faux et contre
l'adaptateur réel.

Option écartée, gardée pour la trace : le modèle Whisper sera à choisir et à mesurer
si le service système disparaît sur un appareil cible, et le poids sur le client
devra alors être arbitré avec l'équipe.
