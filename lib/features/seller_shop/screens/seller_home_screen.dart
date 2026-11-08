import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../seller_orders/screens/seller_orders_screen.dart';
import '../products/screens/my_products_screen.dart';
import '../products/services/product_service.dart';
import '../profile/screens/my_shop_screen.dart';
import '../profile/services/shop_service.dart';

class SellerHomeScreen extends ConsumerStatefulWidget {
  const SellerHomeScreen({
    super.key,
    this.shopRepository,
    this.productRepository,
  });

  final ShopRepository? shopRepository;
  final ProductRepository? productRepository;

  @override
  ConsumerState<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends ConsumerState<SellerHomeScreen> {
  static const _destinations = [
    _SellerDestination(
      label: 'My Order',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    _SellerDestination(
      label: 'My Product',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    _SellerDestination(
      label: 'My Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  int _selectedIndex = 0;
  late final List<Widget> _pages = [
    const SellerOrdersScreen(),
    MyProductsScreen(
      showTitle: false,
      repository:
          widget.productRepository ?? ref.read(productRepositoryProvider),
    ),
    MyShopScreen(
      showAppBar: false,
      repository: widget.shopRepository ?? ref.read(myShopRepositoryProvider),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_selectedIndex];

    return Scaffold(
      appBar: _selectedIndex == 0
          ? null
          : AppBar(title: Text(destination.label), centerTitle: false),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() {
          _selectedIndex = index;
        }),
        destinations: [
          for (final item in _destinations)
            NavigationDestination(
              key: ValueKey(
                'seller-tab-${item.label.toLowerCase().replaceAll(' ', '-')}',
              ),
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _SellerDestination {
  const _SellerDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
