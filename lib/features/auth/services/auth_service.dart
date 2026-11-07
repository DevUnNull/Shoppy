import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json_utils.dart';
import '../models/register_request.dart';
import '../models/user.dart';

class LoginResult {
  const LoginResult({required this.token, this.user});

  final String token;
  final User? user;
}

/// Tên field file ảnh đại diện trong multipart `POST /users/register`.
const registerAvatarField = 'avatar';

class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  /// `POST /auth/login` — body `{email, password}`.
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
      );
      return _parseLogin(data);
    } on ApiException catch (e) {
      // Backend trả 403 (body rỗng) cho tài khoản chưa kích hoạt / bị khoá.
      if (e.statusCode == 403) {
        throw const ApiException(
          'Tài khoản chưa được kích hoạt hoặc đã bị khoá. '
          'Vui lòng kiểm tra email kích hoạt.',
          statusCode: 403,
        );
      }
      rethrow;
    }
  }

  /// `POST /users/register` — multipart: fullName, email, password, phone, avatar.
  Future<void> register(RegisterRequest request) async {
    final form = FormData.fromMap({
      'fullName': request.fullName.trim(),
      'email': request.email.trim(),
      'password': request.password,
      'phone': request.phone.trim(),
      if (request.avatarBytes != null)
        registerAvatarField: MultipartFile.fromBytes(
          request.avatarBytes!,
          filename: request.avatarFileName ?? 'avatar.jpg',
        ),
    });
    await _client.post('/users/register', body: form);
  }

  /// `POST /auth/forgot-password` — backend gửi mã OTP 6 số về email.
  Future<void> forgotPassword(String email) async {
    await _client.post('/auth/forgot-password', body: {'email': email.trim()});
  }

  /// `POST /auth/reset-password` — body `{email, otp, newPassword}`.
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _client.post(
      '/auth/reset-password',
      body: {'email': email.trim(), 'otp': otp, 'newPassword': newPassword},
    );
  }

  /// `POST /auth/logout` — vô hiệu hoá token phía server.
  Future<void> logout() async {
    await _client.post('/auth/logout');
  }

  /// `GET /users/profile` — hồ sơ người dùng của token hiện tại.
  Future<User> getProfile() async {
    final data = await _client.get('/users/profile');
    if (data is! Map) {
      throw const ApiException('Không đọc được thông tin tài khoản.');
    }
    return User.fromJson(asMap(data));
  }

  LoginResult _parseLogin(dynamic data) {
    if (data is String && data.isNotEmpty) return LoginResult(token: data);
    final map = asMap(data);
    final token = asStringOrNull(
      map['token'] ?? map['accessToken'] ?? map['jwt'] ?? map['access_token'],
    );
    if (token == null) {
      throw const ApiException('Đăng nhập thành công nhưng thiếu token.');
    }
    final userJson = map['user'] ?? map['userInfo'] ?? map['profile'];
    return LoginResult(
      token: token,
      user: userJson is Map ? User.fromJson(asMap(userJson)) : null,
    );
  }
}
