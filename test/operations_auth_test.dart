import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoppy/features/auth/models/user.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:shoppy/features/auth/services/auth_service.dart';
import 'package:shoppy/features/seller_orders/models/seller_orders_page.dart';
import 'package:shoppy/features/seller_orders/providers/seller_order_action_provider.dart';
import 'package:shoppy/features/seller_orders/providers/seller_orders_provider.dart';
import 'package:shoppy/features/seller_orders/services/seller_order_service.dart';
import 'package:shoppy/features/shipper_orders/models/cod_balance.dart';
import 'package:shoppy/features/shipper_orders/models/cod_transaction.dart';
import 'package:shoppy/features/shipper_orders/models/shipper_order.dart';
import 'package:shoppy/features/shipper_orders/providers/cod_remittance_provider.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_assign_provider.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_cod_provider.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_delivery_provider.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_orders_provider.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';

import 'cod_api_test.dart' as cod_api;
import 'helpers/cod_fakes.dart';
import 'helpers/customer_fakes.dart';
import 'helpers/seller_order_fakes.dart';
import 'helpers/shipper_order_fakes.dart';
import 'seller_order_service_test.dart' as seller_api;

class SessionAuthService extends FakeAuthService {
  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    profile = User(
      id: email == 'a@example.test' ? 16 : 17,
      email: email,
      fullName: email,
      role: UserRole.shipper,
    );
    return LoginResult(token: 'jwt-$email', user: profile);
  }
}

void main() {
  late ProviderContainer container;
  late SessionAuthService auth;
  late FakeSellerOrderRepository sellerA, sellerB;
  late FakeShipperOrderRepository shipperA, shipperB;
  late FakeCodRepository codA, codB;

  Future<void> login(String account) async {
    await container
        .read(authProvider.notifier)
        .login(email: '$account@example.test', password: 'test-password');
    await container.pump();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = SessionAuthService();
    sellerA = FakeSellerOrderRepository(orders: [makeOrder(id: 1)]);
    sellerB = FakeSellerOrderRepository(orders: [makeOrder(id: 2)]);
    shipperA = FakeShipperOrderRepository(
      driverId: 16,
      backend: FakeShipperBackend([
        makeShipperOrder(),
        makeShipperOrder(id: 7, status: 'SHIPPING', driverId: 16),
      ]),
    );
    shipperB = FakeShipperOrderRepository(
      driverId: 17,
      companyId: 2,
      backend: FakeShipperBackend([makeShipperOrder(companyId: 2)]),
    );
    codA = FakeCodRepository();
    codB = FakeCodRepository(shipperId: 17);
    codB.backend.balances[17] = const CodBalance(
      totalCollected: 200000,
      totalRemitted: 0,
      currentBalance: 200000,
    );
    codB.backend.transactions[17] = [];
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        sellerOrderRepositoryProvider.overrideWith((ref) {
          final token = ref.watch(authProvider.select((s) => s.token));
          return token == 'jwt-a@example.test' ? sellerA : sellerB;
        }),
        shipperOrderRepositoryProvider.overrideWith((ref) {
          final token = ref.watch(authProvider.select((s) => s.token));
          return token == 'jwt-a@example.test' ? shipperA : shipperB;
        }),
        shipperCodRepositoryProvider.overrideWith((ref) {
          final token = ref.watch(authProvider.select((s) => s.token));
          return token == 'jwt-a@example.test' ? codA : codB;
        }),
      ],
    );
    container.read(authProvider);
    await container.pump();
    await login('a');
  });

  tearDown(() {
    container.dispose();
    for (final repo in [sellerA, sellerB]) {
      repo.service.close();
    }
    for (final repo in [shipperA, shipperB]) {
      repo.service.close();
    }
    codA.service.close();
    codB.service.close();
  });

  test(
    'Service được tạo lại khi đổi tài khoản/đăng xuất, giữ khi sửa hồ sơ',
    () async {
      final seller = container.read(sellerOrderServiceProvider);
      final shipper = container.read(shipperOrderServiceProvider);
      container.read(authProvider.notifier).replaceUser(auth.profile);
      expect(container.read(sellerOrderServiceProvider), same(seller));
      expect(container.read(shipperOrderServiceProvider), same(shipper));

      await login('b');
      final nextSeller = container.read(sellerOrderServiceProvider);
      final nextShipper = container.read(shipperOrderServiceProvider);
      expect(nextSeller, isNot(same(seller)));
      expect(nextShipper, isNot(same(shipper)));

      await container.read(authProvider.notifier).logout();
      expect(
        container.read(sellerOrderServiceProvider),
        isNot(same(nextSeller)),
      );
      expect(
        container.read(shipperOrderServiceProvider),
        isNot(same(nextShipper)),
      );
      expect(container.read(authProvider).token, isNull);
    },
  );

  test('JWT trả từ login được gửi bằng Bearer cho Seller và COD', () async {
    final token = container.read(authProvider).token;
    final sellerAdapter = seller_api.MemoryAdapter(
      body: {
        'status': 'success',
        'data': {'content': []},
      },
    );
    final sellerService = SellerOrderService(
      dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = sellerAdapter,
      token: token,
    );
    addTearDown(sellerService.close);
    await sellerService.getOrders(status: 'PENDING', page: 0);
    expect(
      sellerAdapter.requests.single.headers['Authorization'],
      'Bearer $token',
    );

    final codAdapter = cod_api.CodAdapter(
      (options) => cod_api.codResponse({
        'status': 'success',
        'data': {'totalCollected': 0, 'totalRemitted': 0, 'currentBalance': 0},
      }),
    );
    final shipperService = ShipperOrderService(
      dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = codAdapter,
      token: token,
    );
    addTearDown(shipperService.close);
    await shipperService.getCodBalance();
    expect(codAdapter.calls.single.headers['Authorization'], 'Bearer $token');
  });

  test(
    'Mở lại app khôi phục JWT đã lưu và tạo lại service theo phiên đó',
    () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      final beforeRestore = container.read(shipperOrderServiceProvider);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authProvider).token, 'jwt-a@example.test');
      expect(container.read(authProvider).user?.id, 16);
      expect(
        container.read(shipperOrderServiceProvider),
        isNot(same(beforeRestore)),
      );
    },
  );

  test('Không có token thì yêu cầu đăng nhập, không gọi API', () async {
    final sellerAdapter = seller_api.MemoryAdapter();
    final sellerService = SellerOrderService(
      dio: Dio()..httpClientAdapter = sellerAdapter,
    );
    final shipperAdapter = cod_api.CodAdapter(
      (options) => cod_api.codResponse(null),
    );
    final shipperService = ShipperOrderService(
      dio: Dio()..httpClientAdapter = shipperAdapter,
    );
    addTearDown(sellerService.close);
    addTearDown(shipperService.close);
    await expectLater(
      sellerService.getOrders(status: 'PENDING', page: 0),
      throwsA(
        isA<SellerOrderException>().having(
          (e) => e.message,
          'message',
          contains('đăng nhập'),
        ),
      ),
    );
    await expectLater(
      shipperService.getCodBalance(),
      throwsA(
        isA<ShipperOrderException>().having(
          (e) => e.message,
          'message',
          contains('đăng nhập'),
        ),
      ),
    );
    expect(sellerAdapter.requests, isEmpty);
    expect(shipperAdapter.calls, isEmpty);
  });

  test(
    'Response Seller cũ trả muộn không ghi đè đơn của tài khoản mới',
    () async {
      final pending = Completer<SellerOrdersPage>();
      sellerA.onGetOrders = (status, page) => pending.future;
      container.listen(sellerOrdersProvider, (previous, next) {});
      final oldRequest = container
          .read(sellerOrdersProvider.notifier)
          .refresh();
      await login('b');
      container.read(sellerOrdersProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sellerOrdersProvider).orders.single.id, 2);
      pending.complete(
        SellerOrdersPage(orders: [makeOrder(id: 1)], page: 0, hasNext: false),
      );
      await oldRequest;
      expect(container.read(sellerOrdersProvider).orders.single.id, 2);
    },
  );

  test('Đổi tài khoản xóa cache chi tiết Shipper, danh sách và COD', () async {
    container.listen(shipperOrderDetailProvider(6), (previous, next) {});
    container.listen(availableShipperOrdersProvider, (previous, next) {});
    container.listen(codBalanceProvider, (previous, next) {});
    container.listen(
      codTransactionsProvider(CodFilter.all),
      (previous, next) {},
    );
    expect(
      (await container.read(shipperOrderDetailProvider(6).future))
          .shippingCompanyId,
      1,
    );
    expect(
      (await container.read(codBalanceProvider.future)).currentBalance,
      930000,
    );
    expect(
      await container.read(codTransactionsProvider(CodFilter.all).future),
      hasLength(1),
    );

    await login('b');
    expect(
      (await container.read(shipperOrderDetailProvider(6).future))
          .shippingCompanyId,
      2,
    );
    expect(
      (await container.read(availableShipperOrdersProvider.future))
          .single
          .shippingCompanyId,
      2,
    );
    expect(
      (await container.read(codBalanceProvider.future)).currentBalance,
      200000,
    );
    expect(
      await container.read(codTransactionsProvider(CodFilter.all).future),
      isEmpty,
    );
  });

  test('Đổi tài khoản lúc kiểm tra nhận đơn thì dừng trước PUT', () async {
    final pending = Completer<ShipperOrder>();
    shipperA.onDetail = (id) => pending.future;
    final provider = shipperAssignProvider(6);
    final request = container
        .read(provider.notifier)
        .assign(makeShipperOrder());
    await login('b');
    expect(container.read(provider).isBusy, isFalse);
    pending.complete(makeShipperOrder());
    expect(await request, isFalse);
    expect(shipperA.assignCalls, isEmpty);
    expect(shipperB.assignCalls, isEmpty);
  });

  test(
    'Đổi tài khoản lúc kiểm tra quyền giao hàng thì không gửi PUT',
    () async {
      final pending = Completer<List<ShipperOrder>>();
      shipperA.onDeliveries = () => pending.future;
      final order = shipperA.backend.orders[7]!;
      final provider = shipperDeliveryProvider(7);
      final request = container
          .read(provider.notifier)
          .delivered(order, cashCollected: true);
      await Future<void>.delayed(Duration.zero);
      await login('b');
      expect(container.read(provider).isBusy, isFalse);
      pending.complete([order]);
      expect(await request, isFalse);
      expect(shipperA.deliveredCalls, isEmpty);
      expect(shipperB.deliveredCalls, isEmpty);
    },
  );

  test('Đổi tài khoản khi đọc số dư thì không gửi POST nộp tiền', () async {
    final pending = Completer<CodBalance>();
    codA.onBalance = () => pending.future;
    final request = container
        .read(codRemittanceProvider.notifier)
        .submit(5000, 'Ca A');
    await login('b');
    expect(container.read(codRemittanceProvider).isBusy, isFalse);
    expect(container.read(codRemittanceProvider).note, isEmpty);
    pending.complete(codA.backend.balances[16]!);
    expect(await request, isFalse);
    expect(codA.postCalls, isEmpty);
    expect(codB.postCalls, isEmpty);
  });

  test(
    'POST COD phiên cũ hoàn tất không tạo thông báo/biên nhận cho phiên mới',
    () async {
      final pending = Completer<void>();
      codA.onRemit = (amount, note) => pending.future;
      final request = container
          .read(codRemittanceProvider.notifier)
          .submit(5000, 'Ca A');
      await Future<void>.delayed(Duration.zero);
      expect(codA.postCalls, hasLength(1));
      await login('b');
      expect(container.read(codRemittanceProvider).transaction, isNull);
      codA.backend.remit(16, 5000, 'Ca A');
      pending.complete();
      expect(await request, isFalse);
      expect(container.read(codRemittanceProvider).completed, isFalse);
      expect(container.read(codRemittanceProvider).transaction, isNull);
      expect(codB.backend.balances[17]!.currentBalance, 200000);
    },
  );

  test('PUT Seller phiên cũ không tải chi tiết bằng phiên mới', () async {
    final order = makeOrder(status: 'PROCESSING');
    final pending = Completer<void>();
    sellerA.onReady = (id) => pending.future;
    container.listen(sellerOrderActionProvider, (previous, next) {});
    final request = container
        .read(sellerOrderActionProvider.notifier)
        .readyToShip(order);
    await login('b');
    expect(container.read(sellerOrderActionProvider).isBusy, isFalse);
    pending.complete();
    expect(await request, isFalse);
    expect(sellerB.detailCalls, isEmpty);
  });
}
