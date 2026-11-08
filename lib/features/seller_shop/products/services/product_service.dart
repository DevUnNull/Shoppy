import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_providers.dart';
import '../models/seller_product.dart';

enum ProductStockStatus {
  all('ALL'),
  inStock('IN_STOCK'),
  outOfStock('OUT_OF_STOCK');

  const ProductStockStatus(this.apiValue);

  final String apiValue;
}

abstract interface class ProductRepository {
  Future<SellerProductPage> getProducts({
    required ProductStockStatus stockStatus,
    required String keyword,
    required int page,
    required int size,
  });

  Future<ProductDetail> getProductDetails(int productId);

  Future<void> deleteProduct(int productId);

  Future<void> deleteVariant(int variantId);

  Future<void> setProductActive({required int productId, required bool active});

  Future<ProductVariantDetail> setVariantActive({
    required int variantId,
    required bool active,
  });

  Future<ProductVariantDetail> updateVariantStock({
    required int variantId,
    required int stockQuantity,
  });

  Future<ProductVariantDetail> updateVariant({
    required int variantId,
    required String variantName,
    required double price,
    required int stockQuantity,
    required String sku,
    required String? imageUrl,
    XFile? image,
  });

  Future<ProductVariantDetail> addVariant({
    required int productId,
    required String variantName,
    required double price,
    required int stockQuantity,
    required String sku,
    String? imageUrl,
    XFile? image,
  });

  Future<ProductDetail> updateProduct({
    required int productId,
    required String name,
    required String description,
    required int categoryId,
    List<XFile> images = const [],
    List<int> deleteImageIds = const [],
  });

  Future<List<ProductCategory>> getCategories();

  Future<SellerProduct> createProduct({
    required String name,
    required String description,
    required int categoryId,
    required List<XFile> images,
    double? basePrice,
    int? baseStock,
    List<ProductVariantInput> variants = const [],
  });
}

class ProductVariantInput {
  const ProductVariantInput({
    required this.variantName,
    required this.price,
    required this.stockQuantity,
    required this.sku,
    this.image,
  });

  final String variantName;
  final double price;
  final int stockQuantity;
  final String sku;
  final XFile? image;
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductApiService(ref.watch(apiClientProvider)),
);

class ProductApiService implements ProductRepository {
  ProductApiService(this._client);

  final ApiClient _client;

  Map<String, dynamic> _map(Object? data, String message) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException(message);
  }

  Future<ProductVariantDetail> _variantResult(Future<dynamic> result) async =>
      ProductVariantDetail.fromJson(
        _map(await result, 'Phản hồi biến thể sản phẩm không hợp lệ.'),
      );

  @override
  Future<SellerProductPage> getProducts({
    required ProductStockStatus stockStatus,
    required String keyword,
    required int page,
    required int size,
  }) async {
    if (page < 0 || size <= 0) {
      throw ArgumentError(
        'Page must be non-negative and size must be positive.',
      );
    }
    final data = await _client.get(
      '/seller/products',
      query: {
        'stockStatus': stockStatus.apiValue,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        'page': page,
        'size': size,
      },
    );
    return SellerProductPage.fromJson(
      _map(data, 'Phản hồi danh sách sản phẩm không hợp lệ.'),
    );
  }

  @override
  Future<ProductDetail> getProductDetails(int productId) async {
    if (productId <= 0) {
      throw ArgumentError.value(productId, 'productId', 'Must be positive.');
    }
    return ProductDetail.fromJson(
      _map(
        await _client.get('/seller/products/$productId'),
        'Phản hồi chi tiết sản phẩm không hợp lệ.',
      ),
    );
  }

  @override
  Future<void> deleteProduct(int productId) async {
    if (productId <= 0) {
      throw ArgumentError.value(productId, 'productId', 'Must be positive.');
    }
    await _client.delete('/products/$productId');
  }

  @override
  Future<void> deleteVariant(int variantId) async {
    if (variantId <= 0) {
      throw ArgumentError.value(variantId, 'variantId', 'Must be positive.');
    }
    await _client.delete('/products/variants/$variantId');
  }

  @override
  Future<void> setProductActive({
    required int productId,
    required bool active,
  }) async {
    await _client.patch(
      '/products/$productId/status',
      body: {'active': active},
    );
  }

  @override
  Future<ProductVariantDetail> setVariantActive({
    required int variantId,
    required bool active,
  }) => _variantResult(
    _client.patch(
      '/products/variants/$variantId/${active ? 'activate' : 'deactivate'}',
    ),
  );

  @override
  Future<ProductVariantDetail> updateVariantStock({
    required int variantId,
    required int stockQuantity,
  }) {
    if (stockQuantity < 0) {
      throw ArgumentError.value(
        stockQuantity,
        'stockQuantity',
        'Must be non-negative.',
      );
    }
    return _variantResult(
      _client.patch(
        '/products/variants/$variantId/stock',
        body: {'stockQuantity': stockQuantity},
      ),
    );
  }

  @override
  Future<ProductVariantDetail> updateVariant({
    required int variantId,
    required String variantName,
    required double price,
    required int stockQuantity,
    required String sku,
    required String? imageUrl,
    XFile? image,
  }) async {
    final form = await _variantForm(
      variantName: variantName,
      price: price,
      stockQuantity: stockQuantity,
      sku: sku,
      imageUrl: imageUrl,
      image: image,
    );
    return _variantResult(
      _client.put('/products/variants/$variantId', body: form),
    );
  }

  @override
  Future<ProductVariantDetail> addVariant({
    required int productId,
    required String variantName,
    required double price,
    required int stockQuantity,
    required String sku,
    String? imageUrl,
    XFile? image,
  }) async {
    final path = '/products/$productId/variants';
    if (image == null) {
      return _variantResult(
        _client.post(
          path,
          body: {
            'variantName': variantName.trim(),
            'price': price,
            'stockQuantity': stockQuantity,
            'sku': sku.trim(),
            if (imageUrl?.trim().isNotEmpty == true)
              'imageUrl': imageUrl!.trim(),
          },
        ),
      );
    }
    return _variantResult(
      _client.post(
        path,
        body: await _variantForm(
          variantName: variantName,
          price: price,
          stockQuantity: stockQuantity,
          sku: sku,
          imageUrl: imageUrl,
          image: image,
        ),
      ),
    );
  }

  Future<FormData> _variantForm({
    required String variantName,
    required double price,
    required int stockQuantity,
    required String sku,
    required String? imageUrl,
    required XFile? image,
  }) async {
    final form = FormData.fromMap({
      'variantName': variantName.trim(),
      'price': price.toString(),
      'stockQuantity': stockQuantity.toString(),
      if (sku.trim().isNotEmpty) 'sku': sku.trim(),
      if (image == null && imageUrl?.trim().isNotEmpty == true)
        'imageUrl': imageUrl!.trim(),
    });
    if (image != null) {
      form.files.add(
        MapEntry(
          'image',
          MultipartFile.fromBytes(
            await image.readAsBytes(),
            filename: image.name,
          ),
        ),
      );
    }
    return form;
  }

  @override
  Future<ProductDetail> updateProduct({
    required int productId,
    required String name,
    required String description,
    required int categoryId,
    List<XFile> images = const [],
    List<int> deleteImageIds = const [],
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'categoryId': categoryId,
    };
    final Object requestBody;
    if (images.isEmpty) {
      if (deleteImageIds.isNotEmpty) body['deleteImageIds'] = deleteImageIds;
      requestBody = body;
    } else {
      final form = FormData.fromMap(body);
      for (var index = 0; index < deleteImageIds.length; index++) {
        form.fields.add(
          MapEntry('deleteImageIds[$index]', '${deleteImageIds[index]}'),
        );
      }
      for (final image in images) {
        form.files.add(
          MapEntry(
            'images',
            MultipartFile.fromBytes(
              await image.readAsBytes(),
              filename: image.name,
            ),
          ),
        );
      }
      requestBody = form;
    }
    return ProductDetail.fromJson(
      _map(
        await _client.put('/products/$productId', body: requestBody),
        'Phản hồi cập nhật sản phẩm không hợp lệ.',
      ),
    );
  }

  @override
  Future<List<ProductCategory>> getCategories() async {
    final data = await _client.get('/categories');
    final wrapped = {'status': 'success', 'data': data};
    return ProductCategory.listFromResponse(wrapped);
  }

  @override
  Future<SellerProduct> createProduct({
    required String name,
    required String description,
    required int categoryId,
    required List<XFile> images,
    double? basePrice,
    int? baseStock,
    List<ProductVariantInput> variants = const [],
  }) async {
    if (name.trim().isEmpty || categoryId <= 0) {
      throw ArgumentError('Product name and category are required.');
    }
    if (variants.isEmpty && (basePrice == null || baseStock == null)) {
      throw ArgumentError('Single products require price and stock.');
    }
    if (variants.isNotEmpty && (basePrice != null || baseStock != null)) {
      throw ArgumentError('Variant products cannot include base price/stock.');
    }

    final form = FormData.fromMap({
      'name': name.trim(),
      'categoryId': categoryId.toString(),
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (variants.isEmpty) 'basePrice': basePrice!.toString(),
      if (variants.isEmpty) 'baseStock': baseStock!.toString(),
    });

    for (var index = 0; index < variants.length; index++) {
      final variant = variants[index];
      form.fields.addAll([
        MapEntry('variants[$index].variantName', variant.variantName.trim()),
        MapEntry('variants[$index].price', variant.price.toString()),
        MapEntry(
          'variants[$index].stockQuantity',
          variant.stockQuantity.toString(),
        ),
        MapEntry('variants[$index].sku', variant.sku.trim()),
      ]);
      if (variant.image != null) {
        form.files.add(
          MapEntry(
            'variantImages',
            MultipartFile.fromBytes(
              await variant.image!.readAsBytes(),
              filename: variant.image!.name,
            ),
          ),
        );
      }
    }
    for (final image in images) {
      form.files.add(
        MapEntry(
          'images',
          MultipartFile.fromBytes(
            await image.readAsBytes(),
            filename: image.name,
          ),
        ),
      );
    }

    return SellerProduct.fromJson(
      _map(
        await _client.post('/products/create', body: form),
        'Phản hồi tạo sản phẩm không hợp lệ.',
      ),
    );
  }
}
