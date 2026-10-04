class AlertsModel {
  String id;
  String productId;
  DateTime createdAt;
  int estimatedDaysLeft;
  bool statut; // true alerte active sinon résolue
  AlertsModel({
    required this.id,
    required this.productId,
    required this.createdAt,
    required this.estimatedDaysLeft,
    required this.statut,
  });

  factory AlertsModel.fromJson(Map<String, dynamic> json) => AlertsModel(
    id: json['id'],
    productId: json['productId'],
    createdAt: DateTime.parse(json['createdAt']),
    estimatedDaysLeft: json['estimatedDaysLeft'],
    statut: json['statut'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'createdAt': createdAt.toIso8601String(),
    'estimatedDaysLeft': estimatedDaysLeft,
    'statut': statut,
  };

  // AlertsEntity toEntity() => AlertsEntity(
  //   id: id,
  //   productId: productId,
  //   createdAt: createdAt,
  //   estimatedDaysLeft: estimatedDaysLeft,
  //   statut: statut
  // );
}
