import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/entities/alert.dart';

/// Reflète exactement le schéma Firestore officiel (collection "alerts") :
/// type, productId, productName, userId, stockAtCreation,
/// estimatedDaysLeft (optionnel), status, createdAt.
class AlertsModel {
  final String id;
  final String type;
  final String productId;
  final String productName;
  final int stockAtCreation;
  final int? estimatedDaysLeft;
  final String status; // "ACTIVE" ou "RESOLVED"
  final DateTime createdAt;

  /// Date de lecture (centre de notifications), null = alerte non lue.
  final DateTime? readAt;

  const AlertsModel({
    required this.id,
    required this.type,
    required this.productId,
    required this.productName,
    required this.stockAtCreation,
    this.estimatedDaysLeft,
    required this.status,
    required this.createdAt,
    this.readAt,
  });

  /// Construit le modèle à partir d'un document Firestore — gère le
  /// type Timestamp natif, contrairement à un simple DateTime.parse().
  factory AlertsModel.fromFirestore(DocumentSnapshot doc) {
    return AlertsModel.fromMap(doc.id, doc.data() as Map<String, dynamic>?);
  }

  /// Variante testable sans Firestore : [data] peut être null pour un
  /// document vide (les champs ont alors des valeurs par défaut plutôt
  /// qu'une exception au milieu d'une liste d'alertes).
  factory AlertsModel.fromMap(String id, Map<String, dynamic>? data) {
    final valeurs = data ?? const <String, dynamic>{};
    return AlertsModel(
      id: id,
      type: valeurs['type'] as String? ?? '',
      productId: valeurs['productId'] as String? ?? '',
      productName: valeurs['productName'] as String? ?? '',
      stockAtCreation: (valeurs['stockAtCreation'] as num?)?.toInt() ?? 0,
      estimatedDaysLeft: (valeurs['estimatedDaysLeft'] as num?)?.toInt(),
      status: valeurs['status'] as String? ?? 'ACTIVE',
      createdAt:
          (valeurs['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (valeurs['readAt'] as Timestamp?)?.toDate(),
    );
  }

  Alert toEntity() => Alert(
    id: id,
    type: _typeFromString(type),
    productId: productId,
    productName: productName,
    stockAtCreation: stockAtCreation,
    estimatedDaysLeft: estimatedDaysLeft,
    status: status == 'ACTIVE' ? AlertStatus.active : AlertStatus.resolved,
    createdAt: createdAt,
    readAt: readAt,
  );

  static AlertType _typeFromString(String value) {
    switch (value) {
      case 'LOW_STOCK':
        return AlertType.lowStock;
      case 'NEGATIVE_STOCK':
        return AlertType.negativeStock;
      case 'PREDICTED_STOCKOUT':
        return AlertType.predictedStockout;
      default:
        // Type inconnu (données d'une version plus récente, corruption) :
        // on affiche l'alerte en "stock bas" plutôt que de planter la liste.
        return AlertType.lowStock;
    }
  }
}
