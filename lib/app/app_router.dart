import 'package:flutter/material.dart';

import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/catalog/screens/category_screen.dart';
import '../features/catalog/screens/product_detail_screen.dart';
import '../features/catalog/screens/search_screen.dart';
import '../features/seller_orders/screens/seller_orders_screen.dart';
import '../features/shop/screens/shop_screen.dart';

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
}
