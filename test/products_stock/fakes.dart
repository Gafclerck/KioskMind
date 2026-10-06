import 'dart:async';

import 'package:kiosk_mind/features/products_stock/domain/services/product_image_upload_service.dart';

/// Faux service d'upload de photo produit.
///
/// `completer` permet de garder l'appel en suspens, ce qui est le seul moyen
/// d'observer l'indicateur d'activité pendant un téléversement.
class FakeProductImageUploadService implements ProductImageUploadService {
  FakeProductImageUploadService({
    this.urlToReturn,
    this.errorToThrow,
    this.completer,
  });

  /// URL renvoyée quand l'envoi réussit.
  String? urlToReturn;

  /// Erreur levée quand l'envoi échoue.
  ProductImageUploadException? errorToThrow;

  /// Quand il est fourni, l'appel attend ce futur avant de rendre la main.
  Completer<String?>? completer;

  int calls = 0;

  @override
  Future<String?> pickAndUpload() async {
    calls++;
    final Completer<String?>? pending = completer;
    if (pending != null) {
      return pending.future;
    }
    final ProductImageUploadException? error = errorToThrow;
    if (error != null) {
      throw error;
    }
    return urlToReturn;
  }
}
