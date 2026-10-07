# Correspondance de la spécification UI aux tokens de l'application

*Base : `docs/voice/UI_SPECIFICATION.md`*
*Émis le : 2026-10-05*
*Branche : `feat/voice-ui-copilot`*

## 1. Pourquoi ce document

La spécification donne des hex et deux familles de polices. L'application a sa
propre palette et une seule famille. Ce document écrit la correspondance retenue,
une fois, pour que la lecture suivante ne rediscute pas les mêmes dix couleurs et
ne se demande pas si Sora a été oubliée.

**Règle : l'interface vocale n'introduit ni couleur ni police.** Elle consomme les
tokens de `lib/core/theme/`, comme le reste de l'application. Une couleur ou une
police propre au module vocal serait une deuxième identité visuelle dans un produit
qui n'en a qu'une.

## 2. Couleurs

Toutes les couleurs de la spécification ont un équivalent dans l'application. Deux
sont exactes, trois sont très proches, le reste est une correspondance de rôle.

| Rôle | Spécification | Token de l'application | Valeur |
|---|---|---|---|
| Vert de fond, actions | `#0E5B51` | `AppColors.primary` | `#156C61` |
| Vert d'action | `#1A7A6D` | `AppColors.primary` | `#156C61` |
| Vert très sombre, texte | `#1A2E2B` | `colorScheme.onSurface` | `#1E292B` |
| Orange principal | `#E29543` | `AppColors.secondary` | `#E9973E` |
| Fond du panneau | `#FAF9F5` | `colorScheme.surface` | `#FAF9F5` (exact) |
| Fond des cartes | `#FFFFFF` | `colorScheme.surfaceBright` | `#FFFFFF` (exact) |
| Bordure des cartes | `#E7E2DA` | `colorScheme.outlineVariant` | `#DAD8D0` |
| Fond des pictogrammes | `#E6F3F1` | `colorScheme.primaryContainer` | `#D6EAE6` |
| Texte secondaire | `#6B7F7C` | `colorScheme.onSurfaceVariant` | `#6B7A7D` |
| Texte sur vert | `#FFFFFF` | `Colors.white` | `#FFFFFF` (exact) |

### 2.1 La zone verte et le thème sombre

`colorScheme.primary` vaut `#3FBFA9` en thème sombre : un vert clair. Un texte
blanc ou orange par-dessus n'atteint plus le contraste.

La zone vocale n'utilise donc **pas** `colorScheme.primary`. Elle utilise
`AppColors.primary`, qui est une constante et ne change pas de valeur, et elle
compose son texte en blanc et en orange explicites. La zone vocale a donc la même
teinte dans les deux thèmes, ce qui est correct : c'est la même surface de marque,
pas une surface de contenu.

Le panneau clair, lui, reste sur `colorScheme.surface` et suit le thème. Un module
entièrement clair en mode sombre serait une erreur ; la zone vocale est la seule
qui ne suit pas, et c'est délibéré.

## 3. Typographie

La spécification demande Sora pour l'essentiel et Figtree pour le secondaire.
L'application ne déclare que PlusJakartaSans, en 400, 500, 600 et 700
(`pubspec.yaml`). **Ajouter deux familles pour un seul écran n'est pas justifié** :
l'écran vocal doit se lire comme le reste de l'application, pas comme une maquette.

Les deux rôles de la spécification sont donc rendus par deux poids de la même
famille, ce qui produit la même hiérarchie visuelle.

| Élément | Spécification | Style retenu |
|---|---|---|
| Transcription | Sora Bold 20 | `headlineSmall` (20 / w700) |
| Titre de panneau | Sora Bold 16 | `titleMedium` + w700 |
| Titre d'en-tête | Sora Bold 16, orange | `titleMedium` + w700 |
| Nom de produit | Sora Bold 14 | `titleSmall` + w700 |
| Prix de ligne | Sora Bold 15 | `titleMedium` 15 / w700 |
| Montant total | Sora ExtraBold 22 | `headlineMedium` 22 / w700 |
| Sous-titre de statut | Figtree Regular 14 | `labelLarge` (14 / w600) |
| Libellé du total | Figtree Regular 15 | `bodyLarge` 15 |
| Détail de carte | Figtree Regular 12 | `bodySmall` (12 / w400) |
| Action « + Ajouter » | Figtree SemiBold 14 | `labelLarge` (14 / w600) |
| Secondaire | Figtree SemiBold 14 | `labelLarge` (14 / w600) |

### 3.1 Le poids 800

La spécification demande l'ExtraBold (800) pour le montant total. Le projet ne
déclare pas ce poids : `FontWeight.w800` serait rendu avec le fichier 700, c'est-à-dire
identique à w700, pour un asset de plus.

Le total reste visuellement dominant par sa taille (22) et sa teinte
(`AppColors.primary`), pas par son poids. **w700 partout.**

## 4. Éléments de la spécification volontairement non repris

| Section | Élément | Raison |
|---|---|---|
| §5 | Barre système iOS, hauteur 44 px, heure « 09:41 » | La spécification dit elle-même qu'elle peut être omise hors maquette iOS. Une heure factice dans une application réelle mentirait sur l'heure. |
| §11 | Indicateur d'accueil iOS, 134 × 5 px | Idem : la barre système réelle est déjà gérée par `SafeArea`. |
| §2 | Les hex exacts | Remplacés par les tokens, voir §2. |
| §3 | Sora et Figtree | Remplacées par PlusJakartaSans, voir §3. |
| §7.1 | Halo décalé de l'axe (bas-droite) | Conservé. C'est le seul écart de la maquette qui ne soit pas un choix de plateforme. |

## 5. Ce qui n'a pas d'équivalent, et pourquoi

La spécification montre un écran dans un état précis : une commande comprise, deux
produits détectés, un total, et deux boutons « Réessayer » et « Confirmer ». Cette
combinaison suppose un **brouillon attendu avant validation**.

Le module vocal n'a pas de brouillon. `DecisionPolicy` exécute la commande, et ne
demande une confirmation que lorsqu'il a un doute à lever. Une vente sans ambiguïté
est donc écrite avant que le panneau ne s'affiche.

La refonte ne rajoute pas de brouillon : elle rend le panneau honnête sur les états
qui existent, et le libellé de la section suit l'état.

| État | Libellé de section |
|---|---|
| Confirmation en attente | « Produits détectés » |
| Vente enregistrée | « Ce qui a été enregistré » |

Ajouter un brouillon reste possible et serait un travail de domaine : un état de
session qui porte les lignes avant exécution, l'édition d'une ligne, son ajout, son
retrait. Rien de cela n'est dans le périmètre de la refonte d'interface.