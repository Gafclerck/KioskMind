# ADR-001 : STT retenu pour le module vocal

- Statut : **en attente de mesure** (squelette écrit avant la mesure, comme
  l'exige `docs/voice/SPIKE_STT.md`)
- Étape : `docs/voice/PIPELINE.md` 0.5
- Date de la mesure : à remplir
- Décideur : équipe, à partir des chiffres

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

<!-- À RENDRE par l'équipe après la mesure. Ne pas remplir à la place de l'équipe. -->

En attente.

## Conséquences

<!-- À compléter avec la décision. -->

Si l'option 1 est retenue : `SpeechRecognizerPort` de `core/voice_services` (étape
1c) est implémenté par l'adaptateur `speech_to_text` déjà écrit dans le spike, et la
synthèse par `flutter_tts`. Le test de contrat du port s'exécute contre un faux et
contre l'adaptateur réel.

Si l'option 2 est retenue : le modèle Whisper est à choisir et à mesurer, l'ADR est
mis à jour, et le poids sur le client doit être arbitré avec l'équipe.
