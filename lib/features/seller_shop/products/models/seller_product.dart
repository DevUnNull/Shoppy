class SellerProductImage {
  const SellerProductImage({required this.id, required this.imageUrl});

  final int id;
  final String imageUrl;

  factory SellerProductImage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final imageUrl = json['imageUrl'];
    if (id is! num || imageUrl is! String) {
      throw const FormatException('Product image response is invalid.');
    }

    return SellerProductImage(id: id.toInt(), imageUrl: imageUrl);
  }
}

class SellerProduct {
  const SellerProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.thumbnailUrl,
    required this.shopId,
    required this.shopName,
    required this.categoryId,
    required this.categoryName,
    required this.totalStock,
    required this.hasVariants,
    required this.isActive,
    required this.minPrice,
    required this.maxPrice,
    required this.images,
  });

  final int id;
  final String name;
  final String? description;
  final String? thumbnailUrl;
  final int shopId;
  final String shopName;
  final int categoryId;
  final String categoryName;
  final int totalStock;
  final bool hasVariants;
  final bool isActive;
  final double minPrice;
  final double maxPrice;
  final List<SellerProductImage> images;

  factory SellerProduct.fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'];
    if (imagesJson != null && imagesJson is! List) {
      throw const FormatException('Product images must be a list.');
    }
    final productImages = imagesJson as List? ?? const [];

    return SellerProduct(
      id: _intField(json, 'id'),
      name: _stringField(json, 'name'),
      description: _nullableStringField(json, 'description'),
      thumbnailUrl: _nullableStringField(json, 'thumbnailUrl'),
      shopId: _intField(json, 'shopId'),
      shopName: _stringField(json, 'shopName'),
      categoryId: _intField(json, 'categoryId'),
      categoryName: _stringField(json, 'categoryName'),
      totalStock: _intField(json, 'totalStock'),
      hasVariants: _boolField(json, 'hasVariants'),
      isActive: _boolField(json, 'isActive'),
      minPrice: _numberField(json, 'minPrice').toDouble(),
      maxPrice: _numberField(json, 'maxPrice').toDouble(),
      images: List.unmodifiable(
        productImages.map(
          (image) => SellerProductImage.fromJson(
            Map<String, dynamic>.from(image as Map),
          ),
        ),
      ),
    );
  }

  static int _intField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is num) return value.toInt();
    throw FormatException('Product field "$field" must be a number.');
  }

  static String _stringField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is String) return value;
    throw FormatException('Product field "$field" must be a string.');
  }

  static String? _nullableStringField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null || value is String) return value as String?;
    throw FormatException('Product field "$field" must be a string or null.');
  }

  static bool _boolField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is bool) return value;
    throw FormatException('Product field "$field" must be a boolean.');
  }

  static num _numberField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is num) return value;
    throw FormatException('Product field "$field" must be a number.');
  }
}

class ProductDetailImage {
  const ProductDetailImage({required this.id, required this.imageUrl});

  final int? id;
  final String imageUrl;

  factory ProductDetailImage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final imageUrl = json['imageUrl'];
    if ((id != null && id is! num) || imageUrl is! String) {
      throw const FormatException('Product detail image response is invalid.');
    }

    return ProductDetailImage(id: (id as num?)?.toInt(), imageUrl: imageUrl);
  }
}

class ProductVariantDetail {
  const ProductVariantDetail({
    required this.id,
    required this.variantName,
    required this.sku,
    required this.price,
    required this.stockQuantity,
    required this.imageUrl,
    required this.isActive,
    required this.images,
  });

  final int id;
  final String variantName;
  final String? sku;
  final double price;
  final int stockQuantity;
  final String? imageUrl;
  final bool isActive;
  final List<ProductDetailImage> images;

  factory ProductVariantDetail.fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'];
    if (imagesJson != null && imagesJson is! List) {
      throw const FormatException('Variant images must be a list.');
    }
    final variantImages = imagesJson as List? ?? const [];

    return ProductVariantDetail(
      id: _detailIntField(json, 'id'),
      variantName: _detailStringField(json, 'variantName'),
      sku: _detailOptionalStringField(json, 'sku'),
      price: _detailNumberField(json, 'price').toDouble(),
      stockQuantity: _detailIntField(json, 'stockQuantity'),
      imageUrl: _detailNullableStringField(json, 'imageUrl'),
      isActive: _detailBoolField(json, 'isActive'),
      images: List.unmodifiable(
        variantImages.map(
          (image) => ProductDetailImage.fromJson(
            Map<String, dynamic>.from(image as Map),
          ),
        ),
      ),
    );
  }
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.shopId,
    required this.shopName,
    required this.categoryId,
    required this.categoryName,
    required this.totalStock,
    required this.hasVariants,
    required this.isActive,
    required this.images,
    required this.variants,
  });

  final int id;
  final String name;
  final String? description;
  final int shopId;
  final String shopName;
  final int categoryId;
  final String categoryName;
  final int totalStock;
  final bool hasVariants;
  final bool isActive;
  final List<ProductDetailImage> images;
  final List<ProductVariantDetail> variants;

  ProductDetail copyWith({
    bool? isActive,
    int? totalStock,
    bool? hasVariants,
    List<ProductVariantDetail>? variants,
  }) => ProductDetail(
    id: id,
    name: name,
    description: description,
    shopId: shopId,
    shopName: shopName,
    categoryId: categoryId,
    categoryName: categoryName,
    totalStock: totalStock ?? this.totalStock,
    hasVariants: hasVariants ?? this.hasVariants,
    isActive: isActive ?? this.isActive,
    images: images,
    variants: variants ?? this.variants,
  );

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'];
    final variantsJson = json['variants'];
    if ((imagesJson != null && imagesJson is! List) ||
        (variantsJson != null && variantsJson is! List)) {
      throw const FormatException(
        'Product detail images and variants must be lists.',
      );
    }
    final productImages = imagesJson as List? ?? const [];
    final productVariants = variantsJson as List? ?? const [];

    return ProductDetail(
      id: _detailIntField(json, 'id'),
      name: _detailStringField(json, 'name'),
      description: _detailNullableStringField(json, 'description'),
      shopId: _detailIntField(json, 'shopId'),
      shopName: _detailStringField(json, 'shopName'),
      categoryId: _detailIntField(json, 'categoryId'),
      categoryName: _detailStringField(json, 'categoryName'),
      totalStock: _detailIntField(json, 'totalStock'),
      hasVariants: _detailBoolField(json, 'hasVariants'),
      isActive: _detailBoolField(json, 'isActive'),
      images: List.unmodifiable(
        productImages.map(
          (image) => ProductDetailImage.fromJson(
            Map<String, dynamic>.from(image as Map),
          ),
        ),
      ),
      variants: List.unmodifiable(
        productVariants.map(
          (variant) => ProductVariantDetail.fromJson(
            Map<String, dynamic>.from(variant as Map),
          ),
        ),
      ),
    );
  }
}

int _detailIntField(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is num) return value.toInt();
  throw FormatException('Product detail field "$field" must be a number.');
}

String _detailStringField(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String) return value;
  throw FormatException('Product detail field "$field" must be a string.');
}

String? _detailNullableStringField(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null || value is String) return value as String?;
  throw FormatException(
    'Product detail field "$field" must be a string or null.',
  );
}

String? _detailOptionalStringField(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null || value is String) return value as String?;
  if (value is num) return value.toString();
  throw FormatException(
    'Product detail field "$field" must be a string, number, or null.',
  );
}

bool _detailBoolField(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) return value;
  throw FormatException('Product detail field "$field" must be a boolean.');
}

num _detailNumberField(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is num) return value;
  throw FormatException('Product detail field "$field" must be a number.');
}

class ProductCategory {
  const ProductCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['categoryId'];
    final name = json['name'] ?? json['categoryName'];
    if (id is! num || name is! String || name.trim().isEmpty) {
      throw const FormatException('Category response is invalid.');
    }

    return ProductCategory(id: id.toInt(), name: name);
  }

  static List<ProductCategory> listFromResponse(Object? decoded) {
    if (decoded is! Map<String, dynamic> || decoded['status'] != 'success') {
      throw const FormatException('Category response is invalid.');
    }

    final data = decoded['data'];
    final Object? items = data is List
        ? data
        : data is Map
        ? (data['content'] ?? data['categories'])
        : null;
    if (items is! List) {
      throw const FormatException('Category list is missing from response.');
    }

    return List.unmodifiable(
      items.map(
        (category) => ProductCategory.fromJson(
          Map<String, dynamic>.from(category as Map),
        ),
      ),
    );
  }
}

class SellerProductPage {
  const SellerProductPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<SellerProduct> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  factory SellerProductPage.fromJson(Map<String, dynamic> json) {
    final contentJson = json['content'];
    if (contentJson is! List) {
      throw const FormatException('Product page content must be a list.');
    }

    return SellerProductPage(
      content: List.unmodifiable(
        contentJson.map(
          (product) =>
              SellerProduct.fromJson(Map<String, dynamic>.from(product as Map)),
        ),
      ),
      page: _intField(json, 'page'),
      size: _intField(json, 'size'),
      totalElements: _intField(json, 'totalElements'),
      totalPages: _intField(json, 'totalPages'),
      hasNext: _boolField(json, 'hasNext'),
      hasPrevious: _boolField(json, 'hasPrevious'),
    );
  }

  static int _intField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is num) return value.toInt();
    throw FormatException('Page field "$field" must be a number.');
  }

  static bool _boolField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is bool) return value;
    throw FormatException('Page field "$field" must be a boolean.');
  }
}
