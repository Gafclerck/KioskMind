# spikes/stt_tts

Harnais de mesure STT/TTS de l'étape 0.5. **Le protocole est
[`docs/voice/SPIKE_STT.md`](../../docs/voice/SPIKE_STT.md)** : lire ce document
avant de lancer quoi que ce soit. La décision se prend dans
`docs/decisions/ADR-001-stt-retenu.md`.

Ce paquet est un projet Flutter **autonome**, avec son propre `pubspec.yaml`. C'est
volontaire : `speech_to_text` et `flutter_tts` ne servent qu'à la mesure, et le
`pubspec.yaml` principal de l'application ne doit pas les porter.

`spikes/**` est exclu de `analysis_options.yaml` : l'analyseur racine descendait dans
le dossier et échouait sur des URI non résolus dès le premier clone frais, donc en CI.
Ce paquet s'analyse et se teste de son côté.

## Lancer

Mesure en **release** obligatoire, sinon la reconnaissance peut passer par le réseau
et la mesure ne prouve rien :

```bash
flutter run --release        # depuis spikes/stt_tts
flutter analyze
flutter test
```

## Régénérer les 30 phrases

Elles viennent du jeu figé, pas d'une liste écrite à la main. Le script est à la
racine du dépôt :

```bash
dart run tool/select_spike_phrases.dart
```

## Ce que le harnais ne fait pas

Il ne route rien, ne parse rien, ne note pas la qualité de la voix synthétisée. Il
mesure une hypothèse : est-ce que `speech_to_text` reconnaît le français sur ce
téléphone, sans réseau, assez souvent et assez vite. La décision appartient à l'ADR.
