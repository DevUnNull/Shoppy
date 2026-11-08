import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/core/network/api_client.dart';
import 'package:shoppy/features/auth/models/user.dart';
import 'package:shoppy/features/auth/services/auth_service.dart';

/// Opt-in, read-only integration check. Credentials and JWT never enter fixtures.
void main() {
  final email = Platform.environment['SHOPPY_ADMIN_EMAIL'];
  final password = Platform.environment['SHOPPY_ADMIN_PASSWORD'];
  final enabled = email?.isNotEmpty == true && password?.isNotEmpty == true;

  test(
    'Admin thật: đăng nhập, phân trang và đọc chi tiết 5 phân hệ',
    () async {
      String? token;
      final client = ApiClient(readToken: () => token);
      addTearDown(client.close);
      final auth = AuthService(client);
      final login = await auth.login(email: email!, password: password!);
      expect(login.token.isNotEmpty, isTrue);
      token = login.token;
      final profile = await auth.getProfile();
      expect(profile.role, UserRole.admin);

      const endpoints = {
        '/admin/users': '/admin/users',
        '/admin/shops': '/admin/shops',
        '/admin/categories': null,
        '/admin/shipping-companies': '/admin/shipping-companies',
        '/orders/manage': '/orders',
      };
      for (final entry in endpoints.entries) {
        final page = await _readPage(client, entry.key);
        final rows = page['content'] as List;
        if (rows.isEmpty || entry.value == null) continue;
        final row = Map<String, dynamic>.from(rows.first as Map);
        final detail = await client.get('${entry.value}/${row['id']}');
        expect(detail is Map, isTrue, reason: '${entry.value}/id detail');
        final record = Map<String, dynamic>.from(detail as Map);
        expect(record['id'] == row['id'], isTrue);
        debugPrint('${entry.value}/id fields: ${_shape(record)}');
      }

      // Seller and shipper details carry optional linked entities.
      for (final role in ['SELLER', 'SHIPPER']) {
        final page = await _readPage(client, '/admin/users', role: role);
        final rows = page['content'] as List;
        if (rows.isEmpty) continue;
        final row = Map<String, dynamic>.from(rows.first as Map);
        final detail = await client.get('/admin/users/${row['id']}');
        expect(detail is Map, isTrue);
        debugPrint('/admin/users/$role fields: ${_shape(detail)}');
      }
    },
    skip: enabled ? false : 'Đặt SHOPPY_ADMIN_EMAIL và SHOPPY_ADMIN_PASSWORD để chạy với backend thật.',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<Map<String, dynamic>> _readPage(
  ApiClient client,
  String path, {
  String? role,
}) async {
  final data = await client.get(
    path,
    query: {'page': 0, 'size': 1, 'role': ?role},
  );
  expect(data is Map, isTrue, reason: '$path page envelope');
  final page = Map<String, dynamic>.from(data as Map);
  expect(page['content'] is List, isTrue, reason: '$path content');
  expect(page['page'] == 0, isTrue, reason: '$path zero-based page');
  expect(page['size'] == 1, isTrue, reason: '$path page size');
  expect(page['hasNext'] is bool, isTrue, reason: '$path hasNext');
  final rows = page['content'] as List;
  expect(rows.length <= 1, isTrue);
  if (rows.isNotEmpty) debugPrint('$path fields: ${_shape(rows.first)}');
  return page;
}

/// Prints field names/types only, without tokens or personal record values.
String _shape(dynamic value, [int depth = 0]) {
  if (value == null) return 'null';
  if (depth >= 3) return value.runtimeType.toString();
  if (value is Map) {
    return '{${value.entries.map((entry) => '${entry.key}: ${_shape(entry.value, depth + 1)}').join(', ')}}';
  }
  if (value is List) {
    return value.isEmpty ? '[]' : '[${_shape(value.first, depth + 1)}]';
  }
  return value.runtimeType.toString();
}
