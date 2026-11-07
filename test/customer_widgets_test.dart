import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoppy/core/theme/app_theme.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:shoppy/features/auth/screens/login_screen.dart';
import 'package:shoppy/features/auth/widgets/otp_input.dart';
import 'package:shoppy/features/catalog/models/product.dart';
import 'package:shoppy/features/catalog/providers/catalog_providers.dart';
import 'package:shoppy/features/catalog/screens/product_detail_screen.dart';
import 'package:shoppy/features/catalog/screens/search_screen.dart';
import 'package:shoppy/features/catalog/widgets/product_card.dart';
import 'package:shoppy/features/shop/providers/shop_providers.dart';

import 'helpers/customer_fakes.dart';

Widget app(Widget home, {List overrides = const []}) => ProviderScope(
  key: UniqueKey(),
  overrides: [...overrides],
  retry: (_, _) => null,
  child: MaterialApp(theme: AppTheme.light(), home: home),
);

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Đợi toast (2.2s) tự đóng để không còn Timer treo.
Future<void> flushToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('OTP: gõ tự focus ô kế, dán 6 số tự điền hết', (tester) async {
    String code = '';
    String? completed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: OtpInput(
              onChanged: (v) => code = v,
              onCompleted: (v) => completed = v,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '4');
    await tester.pump();
    expect(code, '4');
    expect(tester.widget<TextField>(fields.at(1)).focusNode!.hasFocus, isTrue);

    await tester.enterText(fields.at(0), '123456');
    await tester.pump();
    expect(code, '123456');
    expect(completed, '123456');
  });

  testWidgets('Login: validate trống và đăng nhập thành công', (tester) async {
    await setSize(tester, const Size(500, 900));
    final auth = FakeAuthService();
    await tester.pumpWidget(
      app(
        const LoginScreen(),
        overrides: [authServiceProvider.overrideWithValue(auth)],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('ĐĂNG NHẬP'));
    await tester.pump();
    expect(find.text('Email không được để trống'), findsOneWidget);
    expect(find.text('Mật khẩu không được để trống'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.text('ĐĂNG NHẬP'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Xin chào'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('Search: hiển thị kết quả và Empty State', (tester) async {
    await setSize(tester, const Size(1300, 1000));
    final service = FakeProductService(
      pages: [
        [product(1, name: 'Giày A'), product(2, name: 'Giày B')],
      ],
    );
    await tester.pumpWidget(
      app(
        const SearchScreen(keyword: 'giày'),
        overrides: [
          productServiceProvider.overrideWithValue(service),
          categoryServiceProvider.overrideWithValue(FakeCategoryService()),
        ],
      ),
    );
    expect(find.byType(ProductCardSkeleton), findsWidgets);
    await tester.pump();
    await tester.pump();
    expect(find.byType(ProductCard), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(ProductCard),
        matching: find.text('Giày A'),
      ),
      findsOneWidget,
    );
    expect(service.calls, contains('giày:0'));

    await tester.pumpWidget(
      app(
        const SearchScreen(keyword: 'xyz'),
        overrides: [
          productServiceProvider.overrideWithValue(
            FakeProductService(pages: [[]]),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Không tìm thấy kết quả nào'), findsOneWidget);
  });

  testWidgets('Chi tiết: chọn biến thể đổi giá, disable phân loại hết hàng', (
    tester,
  ) async {
    await setSize(tester, const Size(1300, 1600));
    final detail = ProductDetail(
      product: product(5, price: 100000, name: 'Áo thun'),
      images: const [],
      variants: [
        variant(1, 'Đen / M', price: 100000),
        variant(2, 'Đen / L', price: 150000),
        variant(3, 'Trắng / M', price: 120000),
        variant(4, 'Trắng / L', price: 170000, stock: 0),
      ],
    );
    await tester.pumpWidget(
      app(
        const ProductDetailScreen(productId: 5),
        overrides: [
          productServiceProvider.overrideWithValue(
            FakeProductService(detail: detail),
          ),
          shopServiceProvider.overrideWithValue(FakeShopService()),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('₫100.000 - ₫150.000'),
      findsOneWidget,
      reason: 'khoảng giá còn hàng',
    );
    expect(find.text('Màu sắc'), findsOneWidget);
    expect(find.text('Kích cỡ'), findsOneWidget);

    // Bấm mua khi chưa chọn đủ -> nhắc chọn phân loại.
    await tester.tap(find.text('Mua ngay'));
    await tester.pump();
    expect(find.text('Vui lòng chọn Phân loại hàng'), findsOneWidget);

    await tester.tap(find.text('Trắng'));
    await tester.pump();
    expect(find.text('₫120.000'), findsOneWidget);
    // "L" hết hàng với màu Trắng -> bị gạch/disable.
    final lText = tester.widget<Text>(find.text('L'));
    expect(lText.style!.decoration, TextDecoration.lineThrough);

    await tester.tap(find.text('M'));
    await tester.pump();
    expect(find.text('5 sản phẩm có sẵn'), findsOneWidget);
  });
}
