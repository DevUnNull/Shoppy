import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/catalog/screens/home_screen.dart';
import 'features/seller_orders/screens/seller_orders_screen.dart';
import 'features/shipper_orders/screens/shipper_orders_screen.dart';

void main() {
  runApp(
    ProviderScope(
      // Hiển thị lỗi ngay, không tự động gọi lại API.
      retry: (retryCount, error) => null,
      child: const MyApp(home: ShipperOrdersScreen()),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home = const SellerOrdersScreen()});

  // Mặc định SellerOrdersScreen để giữ các widget test hiện có.
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shoppy',
      theme: AppTheme.light(),
      home: home,
    );
  }
}
