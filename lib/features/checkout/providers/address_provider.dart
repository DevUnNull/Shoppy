import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/checkout_models.dart';

/// Địa chỉ nhận hàng đã lưu theo từng tài khoản (backend chưa có API địa chỉ).
class AddressNotifier extends AsyncNotifier<DeliveryAddress?> {
  String _key(int userId) => 'shoppy.address.$userId';

  @override
  Future<DeliveryAddress?> build() async {
    final user = ref.watch(authProvider.select((s) => s.user));
    if (user == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(user.id));
    if (raw != null) {
      try {
        return DeliveryAddress.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        // Dữ liệu hỏng: dùng gợi ý từ hồ sơ bên dưới.
      }
    }
    // Gợi ý sẵn tên + SĐT từ hồ sơ, người dùng chỉ cần nhập địa chỉ.
    return DeliveryAddress(
      name: user.fullName,
      phone: user.phone ?? '',
      address: '',
    );
  }

  Future<void> save(DeliveryAddress address) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(user.id), jsonEncode(address.toJson()));
    state = AsyncData(address);
  }
}

final addressProvider =
    AsyncNotifierProvider<AddressNotifier, DeliveryAddress?>(
      AddressNotifier.new,
    );
