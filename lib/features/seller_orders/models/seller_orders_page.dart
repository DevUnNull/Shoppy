import 'seller_order.dart';

class SellerOrdersPage {
  const SellerOrdersPage({
    required this.orders,
    required this.page,
    required this.hasNext,
  });

  final List<SellerOrder> orders;
  final int page;
  final bool hasNext;

  factory SellerOrdersPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as List<dynamic>;
    return SellerOrdersPage(
      orders: content
          .map(
            (order) =>
                SellerOrder.fromJson(Map<String, dynamic>.from(order as Map)),
          )
          .toList(),
      page: (json['page'] as num).toInt(),
      hasNext: json['hasNext'] as bool,
    );
  }
}
