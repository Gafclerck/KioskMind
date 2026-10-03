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

  factory SaleModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return SaleModel(
      id: id ?? map['id'] as String?,
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      total: (map['total'] as num).toDouble(),
      items: (map['items'] as List<dynamic>)
          .map(
            (item) => SaleItem(
              productId: item['productId'] as String,
              name: item['name'] as String,
              qty: (item['qty'] as num).toDouble(),
              unitPrice: (item['unitPrice'] as num).toDouble(),
              unitCost: item['unitCost'] != null
                  ? (item['unitCost'] as num).toDouble()
                  : null,
            ),
          )
          .toList(),
      source: map['source'] as String,
      status: map['status'] as String,
      cancelledAt: map['cancelledAt'] != null
          ? (map['cancelledAt'] as Timestamp).toDate()
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
