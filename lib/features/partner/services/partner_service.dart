import '../../../core/network/api_client.dart';

class ShopRegistration {
  const ShopRegistration({
    required this.name,
    required this.address,
    required this.description,
    required this.phone,
  });

  final String name;
  final String address;
  final String description;
  final String phone;

  /// Tên trường theo model Shop (`name, address, description`) + hotline.
  /// Endpoint chặn 403 với tài khoản không phải CUSTOMER nên chưa xác minh được.
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'address': address.trim(),
    'description': description.trim(),
    'phone': phone.trim(),
  };
}

class ShipperRegistration {
  const ShipperRegistration({
    required this.shippingCompanyId,
    required this.identityNumber,
    required this.licensePlate,
    required this.operatingArea,
  });

  /// Bắt buộc (đã xác minh: "Công ty vận chuyển không được để trống").
  final int shippingCompanyId;

  /// Số bằng lái / CCCD.
  final String identityNumber;
  final String licensePlate;
  final String operatingArea;

  Map<String, dynamic> toJson() => {
    'shippingCompanyId': shippingCompanyId,
    'identityNumber': identityNumber.trim(),
    'licenseNumber': identityNumber.trim(),
    'licensePlate': licensePlate.trim(),
    'vehiclePlate': licensePlate.trim(),
    'operatingArea': operatingArea.trim(),
  };
}

class PartnerService {
  PartnerService(this._client);

  final ApiClient _client;

  /// `POST /users/shops/register`
  Future<void> registerShop(ShopRegistration form) async {
    await _client.post('/users/shops/register', body: form.toJson());
  }

  /// `POST /users/shippers/register`
  Future<void> registerShipper(ShipperRegistration form) async {
    await _client.post('/users/shippers/register', body: form.toJson());
  }
}
