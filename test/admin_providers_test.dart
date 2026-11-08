import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/core/network/api_client.dart';
import 'package:shoppy/core/network/api_exception.dart';
import 'package:shoppy/features/admin/models/admin_models.dart';
import 'package:shoppy/features/admin/providers/admin_providers.dart';
import 'package:shoppy/features/admin/services/admin_service.dart';
import 'package:shoppy/features/auth/models/user.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:shoppy/features/catalog/providers/catalog_providers.dart';
import 'package:shoppy/features/orders/providers/order_providers.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => _session(1, UserRole.admin);

  void change(int id, UserRole role) => state = _session(id, role);

  static AuthState _session(int id, UserRole role) => AuthState.authenticated(
    User(id: id, email: 'test@example.test', fullName: 'Test', role: role),
    'token-$id',
  );
}

AdminPage _page(List<int> ids, {int page = 0, bool hasNext = false}) =>
    AdminPage(
      items: ids
          .map((id) => AdminRecord({'id': id, 'name': 'User $id'}))
          .toList(),
      page: page,
      size: 10,
      totalElements: hasNext ? 20 : ids.length,
      totalPages: hasNext || page > 0 ? 2 : 1,
      hasNext: hasNext,
    );

class _Service extends AdminService {
  _Service() : super(ApiClient(readToken: () => null));

  final calls = <AdminQuery>[];
  int mutations = 0;
  Future<AdminPage> Function(AdminQuery)? onList;
  Future<void> Function()? onMutation;

  @override
  Future<AdminPage> list(
    AdminSection section, {
    String search = '',
    String status = '',
    String role = '',
    int page = 0,
    int size = 10,
  }) async {
    final query = AdminQuery(
      search: search,
      status: status,
      role: role,
      page: page,
      size: size,
    );
    calls.add(query);
    return onList == null ? _page([1]) : onList!(query);
  }

  @override
  Future<void> setStatus(AdminSection section, int id, String status) async {
    mutations++;
    await onMutation?.call();
  }
}

void main() {
  late ProviderContainer container;
  late _Service service;
  late AdminListNotifier notifier;
  final provider = adminListProvider(AdminSection.users);

  setUp(() async {
    service = _Service();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_Auth.new),
        adminServiceProvider.overrideWithValue(service),
      ],
    );
    container.listen(provider, (_, _) {});
    notifier = container.read(provider.notifier);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    container.dispose();
    service.client.close();
  });

  test('Bộ lọc trả về muộn không ghi đè kết quả mới', () async {
    final old = Completer<AdminPage>();
    service.onList = (query) async =>
        query.search == 'old' ? old.future : _page([2]);
    final first = notifier.setFilters(search: 'old', role: 'SELLER');
    await notifier.setFilters(
      search: 'new',
      status: 'ACTIVE',
      role: 'CUSTOMER',
    );
    old.complete(_page([3]));
    await first;
    expect(container.read(provider).items.single.id, 2);
    expect(container.read(provider).query.search, 'new');
    expect(container.read(provider).query.role, 'CUSTOMER');
  });

  test(
    'Phân trang gửi đúng trang, thay bộ lọc về trang 0, khử trùng ID',
    () async {
      service.onList = (query) async =>
          _page([1, 1, 2], page: query.page, hasNext: query.page == 0);
      await notifier.goToPage(1);
      expect(container.read(provider).page, 1);
      expect(container.read(provider).items.map((r) => r.id), [1, 2]);
      await notifier.setFilters(status: 'BLOCKED');
      expect(service.calls.last.page, 0);
      expect(service.calls.last.status, 'BLOCKED');
    },
  );

  test(
    'Nhấn mutation liên tục chỉ gửi một yêu cầu và tải lại sau thành công',
    () async {
      final pending = Completer<void>();
      service.onMutation = () => pending.future;
      final before = service.calls.length;
      final first = notifier.mutate(
        (s) => s.setStatus(AdminSection.users, 1, 'BLOCKED'),
      );
      final duplicate = await notifier.mutate(
        (s) => s.setStatus(AdminSection.users, 1, 'BLOCKED'),
      );
      expect(duplicate, isFalse);
      expect(container.read(provider).isMutating, isTrue);
      pending.complete();
      expect(await first, isTrue);
      expect(service.mutations, 1);
      expect(service.calls.length, before + 1);
      expect(container.read(provider).isMutating, isFalse);
    },
  );

  test('Mutation lỗi giữ dữ liệu, hiển thị lỗi và không tự gửi lại', () async {
    service.onMutation = () async =>
        throw const ApiException('Không được khóa');
    expect(
      await notifier.mutate(
        (s) => s.setStatus(AdminSection.users, 1, 'BLOCKED'),
      ),
      isFalse,
    );
    expect(container.read(provider).items.single.id, 1);
    expect(container.read(provider).mutationError, contains('Không được khóa'));
    expect(container.read(provider).isMutating, isFalse);
    expect(service.mutations, 1);
  });

  test('Đổi tài khoản bỏ dữ liệu và response tài khoản cũ', () async {
    final pending = Completer<AdminPage>();
    var first = true;
    service.onList = (_) async {
      if (first) {
        first = false;
        return pending.future;
      }
      return _page([22]);
    };
    final old = notifier.refresh();
    (container.read(authProvider.notifier) as _Auth).change(2, UserRole.admin);
    await Future<void>.delayed(Duration.zero);
    pending.complete(_page([99]));
    await old;
    expect(container.read(provider).items.single.id, 22);
  });

  test('Không phải ADMIN không tải dữ liệu hoặc gửi mutation', () async {
    final before = service.calls.length;
    (container.read(authProvider.notifier) as _Auth).change(
      3,
      UserRole.customer,
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).items, isEmpty);
    expect(container.read(provider).error, contains('không có quyền'));
    await notifier.refresh();
    expect(
      await notifier.mutate(
        (s) => s.setStatus(AdminSection.users, 1, 'BLOCKED'),
      ),
      isFalse,
    );
    expect(service.calls.length, before);
    expect(service.mutations, 0);
  });

  test(
    'Đóng container trong khi mutation đang gửi không đọc Ref đã dispose',
    () async {
      final pending = Completer<void>();
      service.onMutation = () => pending.future;
      final action = notifier.mutate(
        (s) => s.setStatus(AdminSection.users, 1, 'BLOCKED'),
      );
      container.dispose();
      pending.complete();
      expect(await action, isFalse);
      await notifier.refresh();
      await notifier.setFilters(search: 'không còn màn hình');
      await notifier.goToPage(1);
      expect(await notifier.mutate((_) async {}), isFalse);
    },
  );

  test('Sau khi xóa bản ghi cuối trang, quay về trang còn dữ liệu', () async {
    service.onList = (query) async {
      if (query.page == 1) {
        return const AdminPage(
          items: [],
          page: 1,
          size: 10,
          totalElements: 1,
          totalPages: 1,
          hasNext: false,
        );
      }
      return _page([7]);
    };
    await notifier.goToPage(1);
    expect(container.read(provider).page, 0);
    expect(container.read(provider).items.single.id, 7);
  });

  test('Mutation danh mục/hãng làm mới cache công khai tương ứng', () async {
    var categoryLoads = 0;
    var shippingLoads = 0;
    final scoped = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        adminServiceProvider.overrideWithValue(service),
        categoryTreeProvider.overrideWith((_) async {
          categoryLoads++;
          return const [];
        }),
        shippingCompaniesProvider.overrideWith((_) async {
          shippingLoads++;
          return const [];
        }),
      ],
    );
    addTearDown(scoped.dispose);
    scoped.listen(categoryTreeProvider, (_, _) {});
    scoped.listen(shippingCompaniesProvider, (_, _) {});
    await scoped.read(categoryTreeProvider.future);
    await scoped.read(shippingCompaniesProvider.future);
    expect(categoryLoads, 1);
    expect(shippingLoads, 1);
    final categoryNotifier = scoped.read(
      adminListProvider(AdminSection.categories).notifier,
    );
    await Future<void>.delayed(Duration.zero);
    expect(await categoryNotifier.mutate((_) async {}), isTrue);
    await scoped.read(categoryTreeProvider.future);
    expect(categoryLoads, 2);
    expect(shippingLoads, 1);
    final shippingNotifier = scoped.read(
      adminListProvider(AdminSection.shippingCompanies).notifier,
    );
    await Future<void>.delayed(Duration.zero);
    expect(await shippingNotifier.mutate((_) async {}), isTrue);
    await scoped.read(shippingCompaniesProvider.future);
    expect(shippingLoads, 2);
  });
}
