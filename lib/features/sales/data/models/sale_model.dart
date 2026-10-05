import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/sale.dart';

class SaleModel extends Sale {
  SaleModel({
    super.id,
    required super.dateTime,
    required super.createdAt,
    required super.total,
    required super.items,
    required super.source,
    required super.status,
    super.cancelledAt,
  });

  static DateTime _parseDateTime(dynamic value, [DateTime? fallback]) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return fallback ?? DateTime.now();
  }

  factory SaleModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final parsedDateTime = _parseDateTime(map['dateTime']);
    return SaleModel(
      id: id ?? map['id'] as String?,
      dateTime: parsedDateTime,
      createdAt: _parseDateTime(map['createdAt'], parsedDateTime),
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      items: (map['items'] as List<dynamic>? ?? const [])
          .map(
            (item) => SaleItem(
              productId: item['productId'] as String? ?? '',
              name: item['name'] as String? ?? '',
              qty: (item['qty'] as num?)?.toDouble() ?? 0.0,
              unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0.0,
              unitCost: item['unitCost'] != null
                  ? (item['unitCost'] as num).toDouble()
                  : null,
            ),
          )
          .toList(),
      source: map['source'] as String? ?? 'MANUAL',
      status: map['status'] as String? ?? 'COMPLETED',
      cancelledAt: map['cancelledAt'] != null
          ? _parseDateTime(map['cancelledAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dateTime': Timestamp.fromDate(dateTime),
      'createdAt': Timestamp.fromDate(createdAt),
      'total': total,
      'items': items
          .map(
            (item) => {
              'productId': item.productId,
              'name': item.name,
              'qty': item.qty,
              'unitPrice': item.unitPrice,
              'unitCost': item.unitCost,
            },
          )
          .toList(),
      'source': source,
      'status': status,
      'cancelledAt': cancelledAt != null
          ? Timestamp.fromDate(cancelledAt!)
          : null,
    };
  }
}
