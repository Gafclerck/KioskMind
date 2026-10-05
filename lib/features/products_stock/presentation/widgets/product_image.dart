import 'package:flutter/material.dart';

/// Photo d'un produit, avec repli sur l'initiale du nom.
///
/// L'initiale apparaît quand le produit n'a pas de photo, et reste affichée si
/// le chargement échoue : une image cassée vaut mieux qu'un trou vide, et
/// l'utilisateur voit de quoi il s'agit.
///
/// [isBusy] superpose un indicateur pendant un téléversement, pour que le
/// commerce attende devant une photo qui a déjà changé.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 24,
    this.isBusy = false,
    this.onTap,
  });

  /// Nom du produit, dont l'initiale sert de repli.
  final String name;

  /// URL publique de la photo, telle que renvoyée par le stockage d'images.
  final String? imageUrl;

  final double radius;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl;
    final hasPhoto = url != null && url.isNotEmpty;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: hasPhoto ? NetworkImage(url) : null,
      onBackgroundImageError: hasPhoto ? (_, _) {} : null,
      child: hasPhoto
          ? null
          : Text(
              _initial,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.8,
              ),
            ),
    );

    final content = !isBusy
        ? avatar
        : SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                avatar,
                SizedBox(
                  width: radius,
                  height: radius,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          );

    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: content,
    );
  }

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
