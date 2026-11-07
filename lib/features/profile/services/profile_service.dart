import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json_utils.dart';
import '../../auth/models/user.dart';
import '../../auth/widgets/avatar_picker.dart';

/// Tên field file ảnh trong multipart `PUT /users/profile`
/// (cùng quy ước với form đăng ký; chưa xác minh được với backend).
const profileAvatarField = 'avatar';

class ProfileUpdate {
  const ProfileUpdate({
    required this.fullName,
    required this.phone,
    this.gender,
    this.dateOfBirth,
    this.avatar,
  });

  final String fullName;
  final String phone;
  final Gender? gender;
  final DateTime? dateOfBirth;
  final PickedAvatar? avatar;
}

class ProfileService {
  ProfileService(this._client);

  final ApiClient _client;

  /// `PUT /users/profile` (multipart). Trả về hồ sơ mới nếu backend trả kèm.
  Future<User?> updateProfile(ProfileUpdate update) async {
    final dob = update.dateOfBirth;
    final form = FormData.fromMap({
      'fullName': update.fullName.trim(),
      'phone': update.phone.trim(),
      if (update.gender != null) 'gender': update.gender!.value,
      if (dob != null)
        'dateOfBirth':
            '${dob.year.toString().padLeft(4, '0')}-'
            '${dob.month.toString().padLeft(2, '0')}-'
            '${dob.day.toString().padLeft(2, '0')}',
      if (update.avatar != null)
        profileAvatarField: MultipartFile.fromBytes(
          update.avatar!.bytes,
          filename: update.avatar!.fileName,
        ),
    });
    final data = await _client.put('/users/profile', body: form);
    return data is Map ? User.fromJson(asMap(data)) : null;
  }

  /// `PUT /users/change-password` — `{oldPassword, newPassword, confirmPassword}`
  /// (đã xác minh `oldPassword` với backend).
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _client.put(
      '/users/change-password',
      body: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmPassword': newPassword,
      },
    );
  }
}
