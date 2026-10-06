import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/alerts_predictions/data/models/alerts_model.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/entities/alert.dart';

void main() {
  group('AlertsModel.fromMap', () {
    final creeLe = DateTime(2026, 10, 1, 6, 30);

    Map<String, dynamic> documentComplet() => {
      'type': 'LOW_STOCK',
      'productId': 'riz',
      'productName': 'Riz',
      'userId': 'u1',
      'stockAtCreation': 8,
      'status': 'ACTIVE',
      'createdAt': Timestamp.fromDate(creeLe),
    };

    test('mappe un document complet vers l\'entité', () {
      final modele = AlertsModel.fromMap('riz_LOW_STOCK', documentComplet());
      final alerte = modele.toEntity();

      expect(alerte.id, 'riz_LOW_STOCK');
      expect(alerte.type, AlertType.lowStock);
      expect(alerte.productId, 'riz');
      expect(alerte.productName, 'Riz');
      expect(alerte.stockAtCreation, 8);
      expect(alerte.status, AlertStatus.active);
      expect(alerte.createdAt, creeLe);
      expect(alerte.estimatedDaysLeft, isNull);
    });

    test('convertit les nombres en double en int', () {
      final modele = AlertsModel.fromMap('a', {
        ...documentComplet(),
        'stockAtCreation': 8.0,
      });

      expect(modele.stockAtCreation, 8);
      expect(modele.stockAtCreation, isA<int>());
    });

    test('lit estimatedDaysLeft pour une prédiction', () {
      final modele = AlertsModel.fromMap('a', {
        ...documentComplet(),
        'type': 'PREDICTED_STOCKOUT',
        'estimatedDaysLeft': 3,
      });

      expect(modele.toEntity().type, AlertType.predictedStockout);
      expect(modele.estimatedDaysLeft, 3);
    });

    test('convertit le statut RESOLVED', () {
      final modele = AlertsModel.fromMap('a', {
        ...documentComplet(),
        'status': 'RESOLVED',
      });

      expect(modele.toEntity().status, AlertStatus.resolved);
    });

    test('mappe les trois types connus', () {
      const types = {
        'LOW_STOCK': AlertType.lowStock,
        'NEGATIVE_STOCK': AlertType.negativeStock,
        'PREDICTED_STOCKOUT': AlertType.predictedStockout,
      };

      types.forEach((type, attendu) {
        final modele = AlertsModel.fromMap('a', {
          ...documentComplet(),
          'type': type,
        });
        expect(modele.toEntity().type, attendu, reason: type);
      });
    });

    test('un type inconnu retombe sur lowStock sans planter la liste', () {
      final modele = AlertsModel.fromMap('a', {
        ...documentComplet(),
        'type': 'SOMETHING_NEW',
      });

      expect(modele.toEntity().type, AlertType.lowStock);
    });

    test('tolère un document vide', () {
      final modele = AlertsModel.fromMap('vide', null);
      final alerte = modele.toEntity();

      expect(alerte.type, AlertType.lowStock);
      expect(alerte.productId, '');
      expect(alerte.productName, '');
      expect(alerte.stockAtCreation, 0);
      expect(alerte.status, AlertStatus.active);
      expect(alerte.createdAt, isNotNull);
    });

    test('un champ createdAt absent ne casse pas le tri', () {
      final sansDate = {...documentComplet()}..remove('createdAt');

      final alerte = AlertsModel.fromMap('a', sansDate).toEntity();

      expect(alerte.createdAt, isNotNull);
      expect(
        alerte.createdAt.isAfter(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        isTrue,
      );
    });
  });
}
