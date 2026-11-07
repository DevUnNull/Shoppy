import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../models/register_request.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(apiClientProvider)),
);

enum AuthStatus { restoring, authenticated, guest }

class AuthState {
  const AuthState._(this.status, {this.user, this.token});

  const AuthState.restoring() : this._(AuthStatus.restoring);
  const AuthState.guest() : this._(AuthStatus.guest);
  const AuthState.authenticated(User user, String token)
    : this._(AuthStatus.authenticated, user: user, token: token);

  final AuthStatus status;
  final User? user;
  final String? token;

  bool get isLoggedIn => status == AuthStatus.authenticated;
}

/// Global Auth State: đăng nhập / đăng ký / đăng xuất và khôi phục phiên
/// từ bộ nhớ máy (SharedPreferences ~ localStorage).
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState.restoring();
  }

  Future<void> _restore() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.readToken();
    final userJson = await storage.readUser();
    if (!ref.mounted) return;
    if (token == null || token.isEmpty || userJson == null) {
      state = const AuthState.guest();
      return;
    }
    _setToken(token);
    state = AuthState.authenticated(User.fromJson(userJson), token);

    // Làm mới hồ sơ ở nền; token hết hạn thì đăng xuất cục bộ.
    try {
      final fresh = await _service.getProfile();
      if (!ref.mounted || state.token != token) return;
      await storage.save(token: token, user: fresh.toJson());
      state = AuthState.authenticated(fresh, token);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) await _clearLocal();
    } catch (_) {
      // Mất mạng: giữ phiên cũ.
    }
  }

  Future<User> login({required String email, required String password}) async {
    final result = await _service.login(email: email, password: password);
    _setToken(result.token);
    try {
      final user = result.user ?? await _service.getProfile();
      await ref
          .read(tokenStorageProvider)
          .save(token: result.token, user: user.toJson());
      state = AuthState.authenticated(user, result.token);
      return user;
    } catch (_) {
      _setToken(null);
      rethrow;
    }
  }

  /// Đăng ký tài khoản. Backend tạo tài khoản ở trạng thái INACTIVE và gửi
  /// email kích hoạt, nên KHÔNG tự đăng nhập sau khi đăng ký.
  Future<void> register(RegisterRequest request) => _service.register(request);

  /// Tải lại hồ sơ (vd. sau khi nạp ví / đặt hàng bằng ví / sửa hồ sơ).
  Future<User?> refreshProfile() async {
    final token = state.token;
    if (!state.isLoggedIn || token == null) return null;
    final fresh = await _service.getProfile();
    if (!ref.mounted || state.token != token) return null;
    replaceUser(fresh);
    return fresh;
  }

  /// Cập nhật user hiện tại (và bản lưu trên máy) bằng dữ liệu mới.
  void replaceUser(User user) {
    final token = state.token;
    if (token == null) return;
    state = AuthState.authenticated(user, token);
    ref.read(tokenStorageProvider).save(token: token, user: user.toJson());
  }

  Future<void> logout() async {
    try {
      if (state.isLoggedIn) await _service.logout();
    } catch (_) {
      // Token có thể đã hết hạn — vẫn xoá phiên cục bộ.
    }
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    _setToken(null);
    await ref.read(tokenStorageProvider).clear();
    if (ref.mounted) state = const AuthState.guest();
  }

  void _setToken(String? token) =>
      ref.read(authTokenHolderProvider).token = token;
}
