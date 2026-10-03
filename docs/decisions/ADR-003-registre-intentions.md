# ADR-003 : un registre d'intentions indexé par identifiant

- Statut : **proposé**, en attente de validation par l'équipe
- Origine : audit technique du lead, demande **CR-01** (`docs/voice/AUDIT_LEAD_VOICE.md`)
- Date : 2026-10-02
- Décideur : à confirmer

## Contexte

Le module vocal répète partout la liste de ses quatre commandes, et chaque répétition
est une occasion de se tromper.

| Fichier | Ce qu'il répète |
| --- | --- |
| `domain/usecases/execute_command.dart` | un `switch` sur 4 identifiants, 4 méthodes `_runX` quasi identiques |
| `domain/services/command_validator.dart` | un `switch` pour savoir quel prix de référence appliquer |
| `data/parsers/rule_based_parser.dart` | un ensemble d'identifiants qui écrivent, et un `switch` sur la forme des slots |
| `domain/ports/intent_handler.dart` | `kSupportedIntentIds`, et `VoiceHandlers` qui porte 4 champs |

Le catalogue `voice/intent_catalog.json` décrit déjà chaque commande : son risque, la
forme de ses slots, ses déclencheurs. Le code ne le lit pas, il compare des chaînes.

Le commentaire de `intent_handler.dart` affirme pourtant « adding a command means adding
it here, in the catalog, and writing the handler: no other file has to change ». C'est
faux : il faut ajouter le champ du `VoiceHandlers`, l'identifiant à `kSupportedIntentIds`,
une méthode dans l'exécuteur, un cas dans le `switch` du parseur, un cas dans celui du
validateur. Le contrat du module (C4, principe Ouvert/Fermé, et C14 point 6) exige
l'inverse, et il faut donc traiter l'écart.

## Options

### 1. Un registre d'intentions dans le domaine, et le catalogue comme source

`IntentBinding` décrit une commande : son identifiant, comment construire l'entrée
typée à partir d'une proposition, et quelle vente une réussite laisse reprendre. Les
liaisons sont enregistrées à la composition et indexées par identifiant.
`ExecuteCommand` ne connaît plus aucun nom de commande ; le parseur lit le risque et la
forme des slots dans le catalogue ; le validateur y lit le prix de référence.

Acceptation : un test déclare une cinquième commande, entièrement dans le test
(catalogue, handler, liaison), et la fait router sans que `ExecuteCommand`,
`RuleBasedParser` ou `CommandValidator` n'aient changé.

### 2. Un fichier de configuration par commande

Chaque commande devient un fichier décrivant son entrée, son handler et ses effets, lu à
l'exécution. Plus ouvert encore, mais le langage de configuration est une dépendance de
production, et les types perdent la vérification du compilateur.

### 3. Garder les listes, en promettant dans les commentaires qu'il faut les mettre à jour

Aucun coût, aucune migration. Refusée : c'est exactement l'état que l'audit refuse, et
l'écart se reproduira au prochain ajout de commande.

### 4. Supprimer `VoiceHandlers` au profit d'une liste hétérogène

`List<IntentHandler<dynamic, dynamic>>`. Refusée : les types d'entrée et de sortie
disparaissent, et chaque point d'appel redevient une vérification manuelle.

## Décision

**Option 1.**

- `domain/ports/intent_registry.dart` porte `IntentBinding` et `IntentRegistry`. Une
  liaison est enregistrée avec un handler typé et un constructeur d'entrée typé : la
  vérification des types se fait au moment de l'enregistrement, et la liaison ne
  transporte que du résultat effacé. Un seul `as` dans tout le chemin, documenté.
- `data/commands/intent_bindings.dart` construit les quatre liaisons livrées. C'est le
  fichier que la phase I remplacera, liaison par liaison, quand les vrais cas d'usage
  arriveront.
- `ExecuteCommand` garde `dialog`, `clock` et `ids`, perd `handlers` et `undo`, et
  applique ce que la liaison déclare.
- Le catalogue gagne un champ `referencePrice`, déclaré et validé au chargement.
- `kSupportedIntentIds` et `VoiceHandlers` restent : le premier garde le catalogue
  honnête, le second garde les types des quatre ports livrés. Le registre s'ajoute
  devant eux, il ne les remplace pas.
- Le prix de référence passe dans le catalogue plutôt que dans le registre : le
  validateur est un service du domaine, il ne connaît pas la composition.

## Conséquences

- Ajouter une commande : une entrée de catalogue, un handler, une liaison enregistrée à
  la composition. Le parseur, le validateur, l'exécuteur et la politique ne changent pas.
  C'est vérifié par un test, pas par une promesse de commentaire.
- Une commande qui veut une fenêtre d'annulation le déclare dans sa liaison ; plus
  aucun test de type sur `RecordSaleResult` dans l'exécuteur.
- Le `switch` du parseur sur la forme des slots laisse la place à une lecture de
  `SlotType`. Une commande qui déclare une liste de lignes est lue comme telle, une
  commande qui déclare un produit comme un produit, une commande sans slot comme une
  commande sans slot.
- Une commande fictive ne peut pas déclarer un nouveau `IntentInput` depuis un test :
  `IntentInput` est scellée, par choix (les entrées sont un contrat fermé du module).
  Un test réutilise donc un type d'entrée existant. C'est une limite assumée, à revoir
  si un jour le catalogue doit pouvoir ouvrir un nouveau type d'entrée.
- Le prix de référence devient une donnée du catalogue. Le modifier est une décision
  produit (un prix d'achat comparé au prix de vente douterait chaque réception
  correcte), donc il est versionné avec le reste du catalogue.
- `ItemMention.toArguments(intentId)` compare encore un identifiant de commande. Cette
  méthode n'est appelée nulle part ; elle est signalée comme dette d'hygiène, à traiter
  dans une étape de nettoyage et pas ici.