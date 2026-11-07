import 'package:shoppy/core/network/api_client.dart';
import 'package:shoppy/core/network/page_result.dart';
import 'package:shoppy/features/auth/models/register_request.dart';
import 'package:shoppy/features/auth/models/user.dart';
import 'package:shoppy/features/auth/services/auth_service.dart';
import 'package:shoppy/features/catalog/models/product.dart';
import 'package:shoppy/features/catalog/models/variant.dart';
import 'package:shoppy/features/catalog/models/category.dart';
import 'package:shoppy/features/catalog/services/category_service.dart';
import 'package:shoppy/features/catalog/services/product_service.dart';
import 'package:shoppy/features/shop/models/shop.dart';
import 'package:shoppy/features/shop/services/shop_service.dart';

ApiClient dummyClient() => ApiClient(readToken: () => null);

Product product(
  int id, {
  double price = 10000,
  int stock = 10,
  int? categoryId = 1,
  int? sold,
  String? name,
  int shopId = 2,
}) => Product(
  id: id,
  name: name ?? 'Sản phẩm $id',
  minPrice: price,
  maxPrice: price,
  totalStock: stock,
  shopId: shopId,
  shopName: 'Shop $shopId',
  categoryId: categoryId,
  soldCount: sold,
);

Variant variant(
  int id,
  String name, {
  double price = 100000,
  int stock = 5,
  bool active = true,
}) => Variant(
  id: id,
  name: name,
  price: price,
  stockQuantity: stock,
  isActive: active,
);

class FakeProductService extends ProductService {
  FakeProductService({this.pages = const [], this.detail, this.variants})
    : super(dummyClient());

  /// pages[i] = nội dung trang i.
  final List<List<Product>> pages;
  final ProductDetail? detail;
  final List<Variant>? variants;
  final calls = <String>[];
  Object? failOnPage;

  @override
  Future<PageResult<Product>> getProducts({
    String? search,
    int page = 0,
    int size = 24,
  }) async {
    calls.add('${search ?? ''}:$page');
    if (failOnPage == page) throw Exception('Lỗi mạng giả lập');
    final content = page < pages.length ? pages[page] : const <Product>[];
    return PageResult(
      content: content,
      page: page,
      size: size,
      totalElements: pages.fold(0, (sum, p) => sum + p.length),
      totalPages: pages.length,
      hasNext: page + 1 < pages.length,
    );
  }

  @override
  Future<ProductDetail> getProductDetail(int id) async => detail!;

  @override
  Future<List<Variant>> getVariants(int id) async =>
      variants ?? detail!.variants;
}

class FakeAuthService extends AuthService {
  FakeAuthService({this.profile = user}) : super(dummyClient());

  /// Hồ sơ trả về từ getProfile (tuỳ chỉnh số dư ví, vai trò…).
  User profile;

  String? loginError;
  int logoutCalls = 0;
  RegisterRequest? registered;

  static const user = User(
    id: 1,
    email: 'a@b.com',
    fullName: 'Nguyễn Văn A',
    role: UserRole.customer,
  );

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw Exception(loginError);
    return const LoginResult(token: 'jwt-token');
  }

  @override
  Future<User> getProfile() async => profile;

  @override
  Future<void> register(RegisterRequest request) async => registered = request;

  @override
  Future<void> logout() async => logoutCalls++;
}

class FakeShopService extends ShopService {
  FakeShopService() : super(dummyClient());

  @override
  Future<Shop> getShop(int id) async =>
      Shop(id: id, name: 'Shop test', productCount: 3);
}

class FakeCategoryService extends CategoryService {
  FakeCategoryService() : super(dummyClient());

  @override
  Future<List<Category>> getCategoryTree() async => const [];
}
