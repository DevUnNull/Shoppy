import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoppy/core/network/api_providers.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:shoppy/features/cart/providers/cart_provider.dart';
import 'package:shoppy/features/catalog/providers/catalog_providers.dart';
import 'package:shoppy/features/catalog/providers/product_list_provider.dart';

import 'helpers/customer_fakes.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('ProductListNotifier (infinite scroll)', () {
    test('tải trang đầu, loadMore nối trang và khử trùng ID', () async {
      final service = FakeProductService(
        pages: [
          [product(1), product(2)],
          [product(2), product(3)],
        ],
      );
      final container = ProviderContainer(
        overrides: [productServiceProvider.overrideWithValue(service)],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      final sub = container.listen(productListProvider('giày'), (_, _) {});
      addTearDown(sub.close);

      expect(container.read(productListProvider('giày')).isLoading, isTrue);
      await settle();
      expect(container.read(productListProvider('giày')).items.length, 2);

      await container.read(productListProvider('giày').notifier).loadMore();
      final state = container.read(productListProvider('giày'));
      expect(state.items.map((p) => p.id), [1, 2, 3]);
      expect(state.hasNext, isFalse);
      expect(service.calls, ['giày:0', 'giày:1']);

      await container.read(productListProvider('giày').notifier).loadMore();
      expect(service.calls.length, 2, reason: 'hết trang thì không gọi thêm');
    });

    test('lỗi tải thêm giữ dữ liệu cũ và cho thử lại', () async {
      final service = FakeProductService(
        pages: [
          [product(1)],
          [product(2)],
        ],
      )..failOnPage = 1;
      final container = ProviderContainer(
        overrides: [productServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(productListProvider(''), (_, _) {});
      addTearDown(sub.close);
      await settle();

      final notifier = container.read(productListProvider('').notifier);
      await notifier.loadMore();
      expect(container.read(productListProvider('')).loadMoreError, isNotNull);
      expect(container.read(productListProvider('')).items.length, 1);

      service.failOnPage = null;
      await notifier.loadMore();
      expect(container.read(productListProvider('')).items.length, 2);
    });
  });

  group('AuthNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('login lưu token, gắn vào holder; logout xoá sạch', () async {
      final auth = FakeAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      container.read(authProvider);
      await settle();
      expect(container.read(authProvider).status, AuthStatus.guest);

      await container
          .read(authProvider.notifier)
          .login(email: 'a@b.com', password: '123456');
      expect(container.read(authProvider).isLoggedIn, isTrue);
      expect(container.read(authTokenHolderProvider).token, 'jwt-token');
      expect(
        await container.read(tokenStorageProvider).readToken(),
        'jwt-token',
      );

      await container.read(authProvider.notifier).logout();
      expect(auth.logoutCalls, 1);
      expect(container.read(authProvider).status, AuthStatus.guest);
      expect(container.read(authTokenHolderProvider).token, isNull);
      expect(await container.read(tokenStorageProvider).readToken(), isNull);
    });

    test('khôi phục phiên từ bộ nhớ khi mở lại app', () async {
      SharedPreferences.setMockInitialValues({
        'shoppy.auth.token': 'saved',
        'shoppy.auth.user': '{"id":1,"email":"a@b.com","fullName":"A"}',
      });
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(FakeAuthService())],
      );
      addTearDown(container.dispose);
      container.read(authProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final state = container.read(authProvider);
      expect(state.isLoggedIn, isTrue);
      expect(
        state.user!.fullName,
        'Nguyễn Văn A',
        reason: 'đã làm mới profile',
      );
      expect(container.read(authTokenHolderProvider).token, 'saved');
    });

    test('login lỗi không lưu token', () async {
      final auth = FakeAuthService()..loginError = 'Sai mật khẩu';
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      await expectLater(
        container
            .read(authProvider.notifier)
            .login(email: 'a@b.com', password: 'x'),
        throwsException,
      );
      expect(container.read(authTokenHolderProvider).token, isNull);
    });
  });

  test('Cart gộp cùng biến thể và giới hạn theo tồn kho', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    final v = variant(1, 'Đen', stock: 3);
    expect(cart.add(product(1), v, 2, maxStock: 3), 2);
    expect(cart.add(product(1), v, 2, maxStock: 3), 3);
    cart.add(product(1), variant(2, 'Trắng'), 1, maxStock: 5);
    expect(container.read(cartCountProvider), 2);
  });
}
