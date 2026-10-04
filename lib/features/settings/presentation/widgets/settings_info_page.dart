import 'package:flutter/material.dart';

class SettingsInfoPage extends StatelessWidget {
  const SettingsInfoPage({
    super.key,
    required this.title,
    required this.paragraphs,
  });

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            for (int i = 0; i < paragraphs.length; i++) ...[
              Text(
                paragraphs[i],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (i < paragraphs.length - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

const List<String> kHelpParagraphs = <String>[
  'Pour vendre un produit, ouvrez l\u2019onglet « Vendre », recherchez ou '
      'sélectionnez vos produits, puis confirmez le panier.',
  'Vous pouvez enregistrer vos produits dans l\u2019onglet « Stock » : ajoutez '
      'un nom, un prix de vente et un seuil d\u2019alerte.',
  'Le tableau de bord affiche vos ventes du jour, le total encaissé et les '
      'produits en alerte de stock.',
  'Retrouvez l\u2019historique de vos ventes dans l\u2019onglet dédié, et '
      'exportez vos données au format CSV ou PDF depuis les Paramètres.',
  'Votre profil, le nom de votre kiosque et la photo de profil se modifient '
      'dans « Mon profil ».',
];

const List<String> kTermsParagraphs = <String>[
  'En utilisant KioskMind, vous acceptez les présentes conditions '
      'd\u2019utilisation. L\u2019application est destinée à aider les '
      'commerçants à suivre leurs ventes et leur stock.',
  'Vous êtes responsable de l\u2019exactitude des informations saisies et du '
      'matériel sur lequel l\u2019application est installée.',
  'KioskMind fournit l\u2019application « en l\u2019état ». Dans la limite '
      'prévue par la loi, l\u2019éditeur ne garantit pas que le service sera '
      'ininterrompu ou exempt d\u2019erreurs.',
];

const List<String> kPrivacyParagraphs = <String>[
  'Vos données (ventes, produits, profil) sont stockées de façon sécurisée '
      'dans votre espace connecté et ne sont jamais revendues à des tiers.',
  'Seules les informations nécessaires au fonctionnement sont collectées : '
      'identité, contact, activités de vente et préférences locales.',
  'Vous pouvez demander la suppression de votre compte et de vos données à '
      'tout moment. L\u2019assistance vous indiquera la procédure.',
];
