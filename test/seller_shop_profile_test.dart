import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/seller_shop/profile/models/shop.dart';
import 'package:shoppy/features/seller_shop/profile/widgets/shop_summary_card.dart';

void main() {
  final shopJson = <String, dynamic>{
    'id': 1,
    'userId': 1,
    'name': 'Shoppy Flagship Store HCM',
    'balance': 670000.00,
    'totalProducts': 2,
    'totalOrders': 6,
    'status': 'ACTIVE',
    'createdAt': '2026-10-15T18:29:53.401624',
  };

  test('parses product and order totals from /shops/me data', () {
    final shop = Shop.fromJson(shopJson);

    expect(shop.totalProducts, 2);
    expect(shop.totalOrders, 6);
  });

  test('defaults totals to zero when omitted by the API', () {
    final shop = Shop.fromJson(
      {...shopJson}
        ..remove('totalProducts')
        ..remove('totalOrders'),
    );

    expect(shop.totalProducts, 0);
    expect(shop.totalOrders, 0);
  });

  testWidgets('shows product and order totals in the shop summary', (
    tester,
  ) async {
    final shop = Shop.fromJson(shopJson);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ShopSummaryCard(shop: shop)),
      ),
    );

    expect(find.text('Tổng sản phẩm'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Tổng đơn hàng'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });
}
