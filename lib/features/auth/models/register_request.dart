import 'dart:typed_data';

/// Dữ liệu form Đăng ký (gửi lên `POST /users/register` dạng multipart).
class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.phone,
    this.avatarBytes,
    this.avatarFileName,
  });

  final String fullName;
  final String email;
  final String password;
  final String phone;
  final Uint8List? avatarBytes;
  final String? avatarFileName;
}
