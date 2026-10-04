# ADR-002 : localisation par fichiers ARB et `gen_l10n`

- Statut : **proposé**, en attente de validation par l'équipe
- Étape : `docs/voice/PIPELINE.md` 1c, exigence C9
- Date : 2026-10-02
- Décideur : équipe

## Contexte

Le module vocal parle au commerçant et lui affiche un récapitulatif (C6 : « le
récapitulatif est **toujours** aussi affiché à l'écran »). C'est le premier code du
produit qui produit du texte destiné à un humain. C9 interdit alors tout texte
d'utilisateur en dur, et `lib/core/README.md` prévoit déjà un sous-dossier
`core/localization/` pour « i18n setup (FR/EN), translation delegate ».

L'approche doit donc être choisie **avant** le premier widget vocal, pas après : le
contraire coûte une réécriture de chaque widget, et les textes d'un récapitulatif de
vente ne se réécrivent pas à la main sans risque d'erreur sur un montant.

Contraintes retenues :

- pas de dépendance ajoutée « par avance » (C9) ;
- le générateur doit produire du code déterministe et lisible en revue ;
- le pluriel de la monnaie (« un franc » / « deux francs ») doit êtremanaged par
  l'outil, pas par une concaténation ;
- `flutter analyze` doit rester le seul garde-fou de style.

## Options

1. **`gen_l10n` et fichiers ARB, sans dépendance tierce.** `flutter_localizations`
   (paquet du SDK) fournit les delegates, `l10n.yaml` décrit l'arborescence, les
   fichiers `.arb` portent les messages. Le SDK génère
   `AppLocalizations`, avec pluriels et genre gérés par la syntaxe ICU.
   *Pour* : aucune dépendance tierce, outil du SDK donc même version que Flutter,
   pluriels corrects sans code, adding a locale = one file + one line.
   *Contre* : le code généré est dans l'arborescence (le paquet synthétique
   `flutter_gen` a été retiré du SDK), donc il faut le générer avant d'analyser et
   décider s'il est versionné.

2. **`intl` et une table écrite à la main.** Un `Map<String, String>` par langue et
   `Intl.message` pour les pluriels.
   *Pour* : entièrement sous contrôle, rien à générer.
   *Contre* : c'est du code à maintenir, les pluriels et les paramètres deviennent
   du Dart, et chaque langue est une classe de plus.

3. **Textes en dur dans les widgets, i18n plus tard.**
   *Contre* : contraire à C9 dès que l'approche est fixée, et la réécriture
   tomberait sur les(widgetst) qui portent des montants. Rejetée.

## Décision

**Option 1**, `gen_l10n` avec des fichiers ARB.

- `l10n.yaml` déclare `arb-dir`, `template-arb-file`, `output-dir` et
  `output-localization-file`, tous explicites : plus rien ne dépend d'un défaut du
  SDK, qui a déjà changé (`synthetic-package` n'existe plus).
- L'arborescence vit dans `lib/core/localization/`, le dossier prévu par
  `lib/core/README.md` : les fichiers ARB sont des données de traduction partagées,
  pas du code de feature.
- Le dossier `output-dir` est ignoré par git. Le code est régénéré par
  `flutter gen-l10n`, que `flutter build` et `flutter test` déclenchent déjà.
- Une locale se déclare en ajoutant un fichier `.arb` et une entrée dans
  `preferred-supported-locales`, rien d'autre.
- `lib/core/localization/` ne contiendra **que** les données de traduction. Les
  delegates, le sélecteur de langue et le choix de locale au démarrage vont dans la
  racine de composition (`app.dart`), parce que c'est là que se décide le reste.

## Langues

`lib/core/README.md` annonce « FR/EN ». Le module est francophone et le produit vise
le Mali, où l'arabe est une langue de travail. L'arabe n'est **pas** ajouté par cet
ADR : c'est une décision de produit, et inventer des traductions ne serait pas
honorable. Le fichier se crée sans changer une ligne de Dart, ce qui est tout l'objet
de l'option 1.

## Conséquences

- Le premier widget vocal écrit ses textes dans un `.arb`, jamais en dur.
- `flutter analyze` exige le code généré : un `flutter gen-l10n` (ou un build) doit
  précéder la première analyse sur une machine neuve. À intégrer au README.
- Les textes déjà en dur dans `features/onboarding` et `features/auth` ne sont pas
  repris dans cette étape : ils appartiennent à d'autres développeurs, et y toucher
  serait du travail hors périmètre. La dette est réelle et nommée ici.
- Un test vérifie que les `.arb` déclarent les mêmes clés et qu'aucun message ne
  reste non traduit, pour que l'oubli d'une langue soit une erreur de test et pas
  une chaîne vide à l'écran.