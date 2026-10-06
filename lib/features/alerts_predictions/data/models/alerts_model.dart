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

  const AlertsModel({
    required this.id,
    required this.type,
    required this.productId,
    required this.productName,
    required this.stockAtCreation,
    this.estimatedDaysLeft,
    required this.status,
    required this.createdAt,
  });

  /// Construit le modèle à partir d'un document Firestore — gère le
  /// type Timestamp natif, contrairement à un simple DateTime.parse().
  factory AlertsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertsModel(
      id: doc.id,
      type: data['type'] as String,
      productId: data['productId'] as String,
      productName: data['productName'] as String? ?? '',
      stockAtCreation: (data['stockAtCreation'] as num?)?.toInt() ?? 0,
      estimatedDaysLeft: (data['estimatedDaysLeft'] as num?)?.toInt(),
      status: data['status'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
        return AlertType.lowStock;
    }
  }
}
