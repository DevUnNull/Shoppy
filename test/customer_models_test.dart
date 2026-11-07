import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/core/network/page_result.dart';
import 'package:shoppy/core/utils/formatters.dart';
import 'package:shoppy/core/utils/validators.dart';
import 'package:shoppy/features/auth/models/user.dart';
import 'package:shoppy/features/catalog/models/category.dart';
import 'package:shoppy/features/catalog/models/product.dart';
import 'package:shoppy/features/catalog/models/product_sort.dart';
import 'package:shoppy/features/catalog/models/variant_matrix.dart';
import 'package:shoppy/features/shop/models/shop.dart';

import 'helpers/customer_fakes.dart';

void main() {
  group('Parse JSON thật từ backend', () {
    test('PageResult<Product> từ /products/getAll', () {
      final page = PageResult.fromJson({
        'content': [
          {
            'id': 9,
            'name': 'Giày Sneaker Thể Thao Nam',
            'thumbnailUrl': 'https://x/y.jpg',
            'shopId': 2,
            'shopName': 'Shoppy Official Store 2',
            'categoryId': 1,
            'totalStock': 20,
            'hasVariants': false,
            'isActive': true,
            'minPrice': 25000.00,
            'maxPrice': 25000.00,
          },
        ],
        'page': 0,
        'size': 2,
        'totalElements': 8,
        'totalPages': 4,
        'hasNext': true,
      }, Product.fromJson);
      expect(page.totalElements, 8);
      expect(page.hasNext, isTrue);
      final p = page.content.single;
      expect(p.minPrice, 25000);
      expect(p.isMall, isTrue);
      expect(p.soldCount, isNull);
    });

    test('ProductDetail lấy giá từ biến thể khi thiếu min/maxPrice', () {
      final detail = ProductDetail.fromJson({
        'id': 9,
        'name': 'Giày',
        'shopId': 2,
        'totalStock': 20,
        'images': [
          {'id': 11, 'imageUrl': 'https://img/1.jpg'},
        ],
        'variants': [
          {
            'id': 13,
            'variantName': 'Đen / 42',
            'price': 25000,
            'stockQuantity': 20,
            'isActive': true,
          },
          {
            'id': 14,
            'variantName': 'Trắng / 43',
            'price': 30000,
            'stockQuantity': 0,
            'isActive': true,
          },
        ],
      });
      expect(detail.images, ['https://img/1.jpg']);
      expect(detail.product.thumbnailUrl, 'https://img/1.jpg');
      expect(detail.product.minPrice, 25000);
      expect(detail.product.maxPrice, 30000);
      expect(detail.variants.first.name, 'Đen / 42');
    });

    test('Category tree giữ thứ tự và tính descendant ids', () {
      final c = Category.fromJson({
        'id': 1,
        'name': 'Điện tử',
        'displayOrder': 1,
        'children': [
          {
            'id': 12,
            'name': 'Laptop',
            'parentId': 1,
            'displayOrder': 2,
            'children': [],
          },
          {
            'id': 11,
            'name': 'Điện thoại',
            'parentId': 1,
            'displayOrder': 1,
            'children': [],
          },
          {
            'id': 19,
            'name': 'Ẩn',
            'parentId': 1,
            'status': 'INACTIVE',
            'children': [],
          },
        ],
      });
      expect(c.children.map((e) => e.id), [11, 12]);
      expect(c.selfAndDescendantIds, {1, 11, 12});
    });

    test('Shop lấy số sản phẩm từ products.totalElements', () {
      final shop = Shop.fromJson({
        'id': 2,
        'name': 'Shoppy Official Store 2',
        'createdAt': '2026-10-22T16:49:48.538693',
        'products': {'content': [], 'totalElements': 4},
      });
      expect(shop.productCount, 4);
      expect(shop.createdAt!.year, 2026);
    });

    test('User từ /users/profile', () {
      final user = User.fromJson({
        'id': 14,
        'email': 's@x.com',
        'fullName': 'Seller2',
        'role': 'SELLER',
        'balance': 0.00,
      });
      expect(user.isSeller, isTrue);
      expect(User.fromJson(user.toJson()).email, 's@x.com');
    });
  });

  group('VariantMatrix', () {
    final matrix = VariantMatrix.from([
      variant(1, 'Đen / 42', price: 100000),
      variant(2, 'Đen / 43', price: 110000, stock: 0),
      variant(3, 'Trắng / 42', price: 120000),
      variant(4, 'Trắng / 43', price: 130000, active: false),
    ]);

    test('tách thành 2 nhóm và đoán tên nhóm', () {
      expect(matrix.groups.map((g) => g.name), ['Màu sắc', 'Kích cỡ']);
      expect(matrix.groups[0].options, ['Đen', 'Trắng']);
      expect(matrix.groups[1].options, ['42', '43']);
    });

    test('size 43 bị disable vì hết hàng/ngừng bán ở mọi màu', () {
      final none = matrix.emptySelection();
      expect(matrix.isOptionAvailable(1, '43', none), isFalse);
      expect(matrix.isOptionAvailable(1, '42', none), isTrue);
      expect(matrix.isOptionAvailable(0, 'Trắng', ['Trắng', null]), isTrue);
    });

    test('resolve biến thể khi chọn đủ', () {
      expect(matrix.resolve(['Trắng', '42'])!.price, 120000);
      expect(matrix.resolve(['Trắng', null]), isNull);
    });

    test('tên không đồng nhất -> 1 nhóm "Phân loại"', () {
      final m = VariantMatrix.from([
        variant(1, 'Bản thường'),
        variant(2, 'Bản Pro / 256GB'),
      ]);
      expect(m.groups.single.name, 'Phân loại');
      expect(m.groups.single.options, ['Bản thường', 'Bản Pro / 256GB']);
    });

    test('biến thể "Mặc định" là trivial và được chọn sẵn', () {
      final m = VariantMatrix.from([variant(1, 'Mặc định')]);
      expect(m.isTrivial, isTrue);
      expect(m.initialSelection(), ['Mặc định']);
    });
  });

  group('applyCatalogQuery', () {
    final items = [
      product(1, price: 300, categoryId: 1, sold: 5),
      product(2, price: 100, categoryId: 11, stock: 0, sold: 50),
      product(3, price: 200, categoryId: 2, sold: 1),
    ];

    test('lọc theo danh mục', () {
      expect(applyCatalogQuery(items, categoryIds: {1, 11}).map((p) => p.id), [
        1,
        2,
      ]);
    });

    test('sắp xếp giá, mới nhất, bán chạy, phổ biến', () {
      ids(ProductSort s) =>
          applyCatalogQuery(items, sort: s).map((p) => p.id).toList();
      expect(ids(ProductSort.priceAsc), [2, 3, 1]);
      expect(ids(ProductSort.priceDesc), [1, 3, 2]);
      expect(ids(ProductSort.newest), [3, 2, 1]);
      expect(ids(ProductSort.bestSelling), [2, 1, 3]);
      expect(ids(ProductSort.popular), [1, 3, 2]); // hết hàng xuống cuối
    });
  });

  group('Formatters & Validators', () {
    test('định dạng tiền và số rút gọn', () {
      expect(formatVnd(25000), '₫25.000');
      expect(formatPriceRange(12000, 25000), '₫12.000 - ₫25.000');
      expect(formatCompact(999), '999');
      expect(formatCompact(1200), '1,2k');
      expect(formatCompact(15000), '15k');
    });

    test('validator khớp rule backend', () {
      expect(Validators.email('bad'), 'Email không đúng định dạng');
      expect(Validators.email('a@b.com'), isNull);
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
      expect(Validators.phone('0987654321'), isNull);
      expect(Validators.phone('123'), isNotNull);
    });
  });
}
