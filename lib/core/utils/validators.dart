/// Validator khớp với rule phía backend Shoppy (đã kiểm tra thực tế).
abstract final class Validators {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _phone = RegExp(r'^0\d{9}$');

  static String? required(String? value, String label) =>
      (value == null || value.trim().isEmpty)
      ? '$label không được để trống'
      : null;

  static String? email(String? value) {
    final empty = required(value, 'Email');
    if (empty != null) return empty;
    return _email.hasMatch(value!.trim()) ? null : 'Email không đúng định dạng';
  }

  static String? password(String? value) {
    final empty = required(value, 'Mật khẩu');
    if (empty != null) return empty;
    final length = value!.length;
    return (length < 6 || length > 32)
        ? 'Mật khẩu phải từ 6 đến 32 ký tự'
        : null;
  }

  static String? phone(String? value) {
    final empty = required(value, 'Số điện thoại');
    if (empty != null) return empty;
    return _phone.hasMatch(value!.trim())
        ? null
        : 'Số điện thoại không hợp lệ (Ví dụ: 0987654321)';
  }
}
