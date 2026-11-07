import 'package:flutter/material.dart';

import '../features/account/widgets/account_shell.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/catalog/screens/category_screen.dart';
import '../features/catalog/screens/product_detail_screen.dart';
import '../features/cart/providers/cart_provider.dart';
import '../features/catalog/screens/search_screen.dart';
import '../features/checkout/screens/checkout_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/orders/screens/my_orders_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/partner/screens/partner_register_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/seller_orders/screens/seller_orders_screen.dart';
import '../features/shop/screens/shop_screen.dart';
import '../features/wallet/screens/wallet_screen.dart';

/// Điều hướng tập trung cho phân hệ Customer.
abstract final class AppRouter {
  static Future<T?> _push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  static Future<T?> _replace<T>(BuildContext context, Widget page) =>
      Navigator.of(context)
          .pushReplacement<T, Object?>(MaterialPageRoute(builder: (_) => page));

  /// Trả về `true` nếu người dùng đăng nhập thành công.
  static Future<bool> login(
    BuildContext context, {
    bool replace = false,
  }) async {
    final result = replace
        ? await _replace<bool>(context, const LoginScreen())
        : await _push<bool>(context, const LoginScreen());
    return result ?? false;
  }

  static Future<void> register(BuildContext context, {bool replace = false}) =>
      replace
      ? _replace(context, const RegisterScreen())
      : _push(context, const RegisterScreen());

  static Future<void> forgotPassword(BuildContext context) =>
      _push(context, const ForgotPasswordScreen());

  static Future<void> search(
    BuildContext context,
    String keyword, {
    bool replace = false,
  }) => replace
      ? _replace(context, SearchScreen(keyword: keyword))
      : _push(context, SearchScreen(keyword: keyword));

  static Future<void> category(BuildContext context, {int? categoryId}) =>
      _push(context, CategoryScreen(initialCategoryId: categoryId));

  static Future<void> product(BuildContext context, int productId) =>
      _push(context, ProductDetailScreen(productId: productId));

  static Future<void> shop(BuildContext context, int shopId) =>
      _push(context, ShopScreen(shopId: shopId));

  static Future<void> sellerChannel(BuildContext context) =>
      _push(context, const SellerOrdersScreen());

  static void backToHome(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  // ---------------- FE2: Checkout, Đơn mua, Ví, Hồ sơ ----------------

  static Future<void> checkout(BuildContext context, List<CartItem> items) =>
      _push(context, CheckoutScreen(items: items));

  static Widget _accountPage(AccountSection section) => switch (section) {
    AccountSection.profile => const ProfileScreen(),
    AccountSection.password => const ProfileScreen(changePassword: true),
    AccountSection.orders => const MyOrdersScreen(),
    AccountSection.wallet => const WalletScreen(),
    AccountSection.notifications => const NotificationsScreen(),
    AccountSection.partner => const PartnerRegisterScreen(),
  };

  /// Mở một mục trong trang tài khoản. `replace: true` khi chuyển mục từ
  /// sidebar để không chồng nhiều trang tài khoản lên nhau.
  static Future<void> account(
    BuildContext context,
    AccountSection section, {
    bool replace = false,
  }) => replace
      ? _replace(context, _accountPage(section))
      : _push(context, _accountPage(section));

  static Future<void> orderDetail(BuildContext context, int orderId) =>
      _push(context, OrderDetailScreen(orderId: orderId));

  /// Sau khi đặt hàng: về trang chủ rồi mở "Đơn mua".
  static void ordersAfterCheckout(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.push(MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
  }
}
