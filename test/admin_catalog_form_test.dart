import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/core/theme/app_theme.dart';
import 'package:shoppy/features/admin/widgets/admin_catalog_form.dart';

Future<void> openForm(
  WidgetTester tester, {
  bool category = true,
  Map<String, dynamic>? initial,
  required AdminCatalogSave onSave,
  void Function(bool)? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showAdminCatalogForm(
                context,
                isCategory: category,
                initial: initial,
                onSave: onSave,
              );
              onResult?.call(result);
            },
            child: const Text('Mở'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
}

Finder field(String name) => find.byKey(ValueKey('admin-form-$name'));

void main() {
  testWidgets('Category requires name and valid slug; no invalid request', (
    tester,
  ) async {
    var calls = 0;
    await openForm(tester, onSave: (_, _, _) async => calls++);
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Vui lòng nhập thông tin này'), findsNWidgets(2));
    await tester.enterText(field('name'), 'Điện tử');
    await tester.enterText(field('slug'), 'Điện tử');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Slug gồm chữ thường, số và dấu gạch nối'),
      findsOneWidget,
    );
    expect(calls, 0);
  });

  testWidgets('Category saves trimmed data and null root parent', (
    tester,
  ) async {
    Map<String, dynamic>? values;
    Uint8List? image;
    bool? result;
    await openForm(
      tester,
      onSave: (fields, bytes, _) async {
        values = fields;
        image = bytes;
      },
      onResult: (value) => result = value,
    );
    await tester.enterText(field('name'), ' Điện tử ');
    await tester.enterText(field('slug'), ' dien-tu ');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(values, {
      'name': 'Điện tử',
      'slug': 'dien-tu',
      'parentId': null,
      'displayOrder': 0,
    });
    expect(image, isNull);
    expect(result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Edit category rejects own parent and negative display order', (
    tester,
  ) async {
    var calls = 0;
    await openForm(
      tester,
      initial: {'id': 5, 'name': 'Áo', 'slug': 'ao', 'displayOrder': 2},
      onSave: (_, _, _) async => calls++,
    );
    await tester.enterText(field('parentId'), '5');
    await tester.enterText(field('displayOrder'), '-1');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(find.text('Danh mục không thể là cha của chính nó'), findsOneWidget);
    expect(find.text('Nhập số nguyên không âm'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('Shipping validates contact data, then sends exact fields', (
    tester,
  ) async {
    Map<String, dynamic>? values;
    await openForm(
      tester,
      category: false,
      initial: {
        'id': 1,
        'name': 'Giao nhanh',
        'code': 'GN',
        'baseFee': 30000,
        'email': 'bad',
        'website': 'ftp://test.vn',
      },
      onSave: (fields, _, _) async => values = fields,
    );
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    expect(
      find.text('Nhập địa chỉ http:// hoặc https:// hợp lệ'),
      findsOneWidget,
    );
    expect(values, isNull);
    await tester.enterText(field('email'), 'support@test.vn');
    await tester.enterText(field('website'), 'https://test.vn');
    await tester.enterText(field('phone'), '19001206');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(values, {
      'name': 'Giao nhanh',
      'code': 'GN',
      'baseFee': 30000,
      'phone': '19001206',
      'email': 'support@test.vn',
      'website': 'https://test.vn',
    });
  });

  testWidgets('Editing shipping omits contacts not returned by the API', (
    tester,
  ) async {
    Map<String, dynamic>? values;
    await openForm(
      tester,
      category: false,
      initial: {'id': 1, 'name': 'Giao nhanh', 'code': 'GN', 'baseFee': 30000},
      onSave: (fields, _, _) async => values = fields,
    );
    await tester.enterText(field('name'), 'Giao nhanh mới');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(values, {'name': 'Giao nhanh mới', 'code': 'GN', 'baseFee': 30000});
  });

  testWidgets('Editing shipping can clear a known contact explicitly', (
    tester,
  ) async {
    Map<String, dynamic>? values;
    await openForm(
      tester,
      category: false,
      initial: {
        'id': 1,
        'name': 'Giao nhanh',
        'code': 'GN',
        'baseFee': 30000,
        'phone': '19001206',
      },
      onSave: (fields, _, _) async => values = fields,
    );
    await tester.enterText(field('phone'), '');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(values, {
      'name': 'Giao nhanh',
      'code': 'GN',
      'baseFee': 30000,
      'phone': '',
    });
  });

  testWidgets('Creating shipping keeps optional contact fields', (
    tester,
  ) async {
    Map<String, dynamic>? values;
    await openForm(
      tester,
      category: false,
      onSave: (fields, _, _) async => values = fields,
    );
    await tester.enterText(field('name'), 'Giao nhanh');
    await tester.enterText(field('code'), 'GN');
    await tester.enterText(field('baseFee'), ' 30000 ');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(values, {
      'name': 'Giao nhanh',
      'code': 'GN',
      'baseFee': 30000,
      'phone': '',
      'email': '',
      'website': '',
    });
  });

  testWidgets('Saving locks fields and prevents duplicate save or dismissal', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<void>();
    await openForm(
      tester,
      initial: {'id': 1, 'name': 'Áo', 'slug': 'ao'},
      onSave: (_, _, _) {
        calls++;
        return pending.future;
      },
    );
    await tester.tap(field('save'));
    await tester.pump();
    await tester.tap(field('save'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<TextFormField>(field('name')).enabled, isFalse);
    expect(tester.widget<FilledButton>(field('save')).onPressed, isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Server error preserves inputs and permits retry', (
    tester,
  ) async {
    var calls = 0;
    await openForm(
      tester,
      initial: {'id': 1, 'name': 'Áo', 'slug': 'ao'},
      onSave: (_, _, _) async {
        calls++;
        if (calls == 1) throw Exception('Danh mục đang có sản phẩm');
      },
    );
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Danh mục đang có sản phẩm'), findsOneWidget);
    expect(tester.widget<TextFormField>(field('name')).controller!.text, 'Áo');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Shipping requires a finite nonnegative fee and accepts zero', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await openForm(
      tester,
      category: false,
      onSave: (fields, _, _) async => saved = fields,
    );
    await tester.enterText(field('name'), 'Giao nhanh');
    await tester.enterText(field('code'), 'GN');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập cước phí'), findsOneWidget);
    expect(saved, isNull);
    for (final value in ['-1', 'abc', 'NaN', 'Infinity']) {
      await tester.enterText(field('baseFee'), value);
      await tester.tap(field('save'));
      await tester.pumpAndSettle();
      expect(find.text('Cước phí phải là số không âm hợp lệ'), findsOneWidget);
      expect(saved, isNull);
    }
    await tester.enterText(field('baseFee'), '0');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(saved?['baseFee'], 0);
  });

  testWidgets('Editing shipping prefills and updates its fee', (tester) async {
    Map<String, dynamic>? saved;
    await openForm(
      tester,
      category: false,
      initial: {
        'id': 1,
        'name': 'Giao nhanh',
        'code': 'GN',
        'baseFee': 30000.5,
      },
      onSave: (fields, _, _) async => saved = fields,
    );
    expect(
      tester.widget<TextFormField>(field('baseFee')).controller!.text,
      '30000.5',
    );
    await tester.enterText(field('baseFee'), ' 45000.5 ');
    await tester.tap(field('save'));
    await tester.pumpAndSettle();
    expect(saved?['baseFee'], 45000.5);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Small screen form scrolls without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openForm(tester, category: false, onSave: (_, _, _) async {});
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
