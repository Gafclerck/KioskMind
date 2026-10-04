class DailyStats {
  final double revenue;
  final double cost;
  final int salesCount;
  final Map<String, double> qtyByProduct;

  DailyStats({
    required this.revenue,
    required this.cost,
    required this.salesCount,
    required this.qtyByProduct,
  });
}
