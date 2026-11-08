import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/core/network/api_client.dart';
import 'package:shoppy/core/network/api_exception.dart';
import 'package:shoppy/features/admin/models/admin_models.dart';
import 'package:shoppy/features/admin/services/admin_service.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final ResponseBody Function(RequestOptions) respond;
  final calls = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(dynamic data, {int code = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Map<String, dynamic> _page() => {
  'content': [
    {'id': 9, 'name': 'Bản ghi', 'status': 'ACTIVE'},
  ],
  'page': 2,
  'size': 10,
  'totalElements': 31,
  'totalPages': 4,
  'hasNext': true,
};

AdminService _service(_Adapter adapter, {String? Function()? readToken}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  final client = ApiClient(
    dio: dio,
    readToken: readToken ?? () => 'admin-test',
  );
  addTearDown(client.close);
  return AdminService(client);
}

void main() {
  for (final section in AdminSection.values) {
    test(
      '${section.name}: đúng endpoint, bộ lọc, trang và token đăng nhập',
      () async {
        final adapter = _Adapter(
          (_) => _response({'status': 'success', 'data': _page()}),
        );
        final page = await _service(adapter).list(
          section,
          search: '  tìm kiếm  ',
          role: 'SELLER',
          status: section.statuses.first,
          page: 2,
          size: 10,
        );
        final request = adapter.calls.single;
        expect(request.method, 'GET');
        expect(request.path, section.path);
        expect(request.headers['Authorization'], 'Bearer admin-test');
        expect(request.queryParameters, {
          if (section.supportsSearch) 'search': 'tìm kiếm',
          if (section == AdminSection.users) 'role': 'SELLER',
          'status': section.statuses.first,
          'page': 2,
          'size': 10,
        });
        expect(page.items.single.id, 9);
        expect(page.page, 2);
        expect(page.hasNext, isTrue);
        expect(page.totalPages, 4);
      },
    );
  }

  test('Client đọc token mới mỗi request, không dùng JWT cố định', () async {
    var token = 'first-admin';
    final adapter = _Adapter(
      (_) => _response({'status': 'success', 'data': _page()}),
    );
    final service = _service(adapter, readToken: () => token);
    await service.list(AdminSection.users);
    token = 'second-admin';
    await service.list(AdminSection.shops);
    expect(adapter.calls[0].headers['Authorization'], 'Bearer first-admin');
    expect(adapter.calls[1].headers['Authorization'], 'Bearer second-admin');
  });

  test('Chi tiết user/shop/hãng/đơn giữ thông tin lồng nhau', () async {
    final adapter = _Adapter(
      (_) => _response({
        'status': 'success',
        'data': {
          'id': 4,
          'fullName': 'Người dùng',
          'balance': 12500,
          'shop': {'id': 11, 'name': 'Shop liên kết'},
          'vehicle': {'licensePlate': '59A-12345'},
        },
      }),
    );
    final service = _service(adapter);
    for (final section in [
      AdminSection.users,
      AdminSection.shops,
      AdminSection.shippingCompanies,
      AdminSection.orders,
    ]) {
      final detail = await service.detail(section, 4);
      expect(detail.raw['shop']['name'], 'Shop liên kết');
      expect(detail.raw['vehicle']['licensePlate'], '59A-12345');
      expect(detail.balance, 12500);
    }
    expect(adapter.calls.map((r) => r.path), [
      '/admin/users/4',
      '/admin/shops/4',
      '/admin/shipping-companies/4',
      '/orders/4',
    ]);
  });

  test('PATCH trạng thái/role, DELETE và hủy đơn gửi đúng body', () async {
    final adapter = _Adapter((_) => _response({'status': 'success'}));
    final service = _service(adapter);
    await service.setStatus(AdminSection.users, 2, 'BLOCKED');
    await service.setStatus(AdminSection.shops, 3, 'ACTIVE');
    await service.setStatus(AdminSection.categories, 4, 'INACTIVE');
    await service.setStatus(AdminSection.shippingCompanies, 5, 'INACTIVE');
    await service.setUserRole(2, 'SHIPPER');
    await service.delete(AdminSection.categories, 4);
    await service.delete(AdminSection.shippingCompanies, 5);
    await service.cancelOrder(8, '  Kiểm tra gian lận  ');
    expect(adapter.calls.map((r) => '${r.method} ${r.path}'), [
      'PATCH /admin/users/2/status',
      'PATCH /admin/shops/3/status',
      'PATCH /admin/categories/4/status',
      'PATCH /admin/shipping-companies/5/status',
      'PATCH /admin/users/2/role',
      'DELETE /admin/categories/4',
      'DELETE /admin/shipping-companies/5',
      'PUT /orders/8/cancel',
    ]);
    expect(adapter.calls[0].data, {'status': 'BLOCKED'});
    expect(adapter.calls[4].data, {'role': 'SHIPPER'});
    expect(adapter.calls.last.data, {'reason': 'Kiểm tra gian lận'});
  });

  test('Tạo/sửa danh mục JSON truyền parentId null và displayOrder', () async {
    final adapter = _Adapter((_) => _response({'status': 'success'}));
    final service = _service(adapter);
    await service.saveCategory(name: '  Điện tử  ', slug: 'dien-tu');
    await service.saveCategory(
      id: 8,
      name: 'Điện thoại',
      slug: 'dien-thoai',
      parentId: 3,
      displayOrder: 2,
    );
    expect(adapter.calls[0].method, 'POST');
    expect(adapter.calls[0].data, {
      'name': 'Điện tử',
      'slug': 'dien-tu',
      'parentId': null,
      'displayOrder': 0,
    });
    expect(adapter.calls[1].method, 'PUT');
    expect(adapter.calls[1].path, '/admin/categories/8');
    expect(adapter.calls[1].data['parentId'], 3);
  });

  test('Ảnh danh mục và logo hãng dùng đúng field multipart', () async {
    final adapter = _Adapter((_) => _response({'status': 'success'}));
    final service = _service(adapter);
    final image = AdminUpload(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'icon.png',
    );
    await service.saveCategory(name: 'Áo', slug: 'ao', image: image);
    await service.saveShippingCompany(
      id: 7,
      name: 'Giao hàng',
      code: 'GH',
      phone: '1900123',
      email: 'ship@example.test',
      website: 'https://example.test',
      logo: image,
    );
    final category = adapter.calls[0].data as FormData;
    final company = adapter.calls[1].data as FormData;
    expect(category.files.single.key, 'image');
    expect(category.files.single.value.filename, 'icon.png');
    expect(Map.fromEntries(category.fields)['parentId'], '');
    expect(company.files.single.key, 'logo');
    expect(Map.fromEntries(company.fields), {
      'name': 'Giao hàng',
      'code': 'GH',
      'phone': '1900123',
      'email': 'ship@example.test',
      'website': 'https://example.test',
    });
    expect(adapter.calls[1].path, '/admin/shipping-companies/7');
  });

  test('Tạo hãng JSON và chi tiết sai ID được kiểm tra', () async {
    final adapter = _Adapter(
      (_) => _response({
        'status': 'success',
        'data': {'id': 99},
      }),
    );
    final service = _service(adapter);
    await service.saveShippingCompany(name: 'Hãng mới', code: 'MOI');
    expect(adapter.calls.single.method, 'POST');
    expect(adapter.calls.single.data, {'name': 'Hãng mới', 'code': 'MOI'});
    await expectLater(
      service.detail(AdminSection.users, 4),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'Sửa hãng không xóa contact bị thiếu trong response, cho phép xóa rõ ràng',
    () async {
      final adapter = _Adapter((_) => _response({'status': 'success'}));
      final service = _service(adapter);
      await service.saveShippingCompany(id: 3, name: 'Hãng', code: 'GH');
      expect(adapter.calls[0].data, {'name': 'Hãng', 'code': 'GH'});
      await service.saveShippingCompany(
        id: 3,
        name: 'Hãng',
        code: 'GH',
        phone: '',
        email: '   ',
        website: 'https://example.test',
      );
      expect(adapter.calls[1].data, {
        'name': 'Hãng',
        'code': 'GH',
        'phone': '',
        'email': '',
        'website': 'https://example.test',
      });
    },
  );

  for (final code in [401, 403, 409, 500]) {
    test('HTTP $code giữ lỗi backend, mutation chỉ gửi một lần', () async {
      final adapter = _Adapter(
        (_) => _response({'message': 'Từ chối thao tác'}, code: code),
      );
      await expectLater(
        _service(adapter).setStatus(AdminSection.users, 2, 'BLOCKED'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', code),
        ),
      );
      expect(adapter.calls.length, 1);
    });
  }

  test(
    'Response danh sách hỏng và status error không được coi thành công',
    () async {
      final malformed = _Adapter(
        (_) => _response({'status': 'success', 'data': {}}),
      );
      await expectLater(
        _service(malformed).list(AdminSection.users),
        throwsA(isA<ApiException>()),
      );
      final rejected = _Adapter(
        (_) =>
            _response({'status': 'error', 'message': 'Danh mục còn sản phẩm'}),
      );
      await expectLater(
        _service(rejected).delete(AdminSection.categories, 1),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
