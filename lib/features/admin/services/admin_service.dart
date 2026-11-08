import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/admin_models.dart';

/// All administrator requests use the current authenticated shared client.
/// Mutation requests are sent exactly once; no retry interceptor is added.
class AdminService {
  AdminService(this.client);

  final ApiClient client;

  Future<AdminPage> list(
    AdminSection section, {
    String search = '',
    String status = '',
    String role = '',
    int page = 0,
    int size = 10,
  }) async {
    if (page < 0 || size <= 0) {
      throw ArgumentError('Trang và kích thước trang không hợp lệ.');
    }
    final data = await client.get(
      section.path,
      query: {
        if (section.supportsSearch && search.trim().isNotEmpty)
          'search': search.trim(),
        if (status.isNotEmpty) 'status': status,
        if (section.supportsRole && role.isNotEmpty) 'role': role,
        'page': page,
        'size': size,
      },
    );
    return AdminPage.fromJson(data, page: page, size: size);
  }

  Future<AdminRecord> detail(AdminSection section, int id) async {
    _validateId(id);
    if (!section.supportsDetail) {
      throw ArgumentError('Danh mục dùng thông tin có sẵn trong danh sách.');
    }
    final path = section == AdminSection.orders
        ? '/orders/$id'
        : '${section.path}/$id';
    final data = await client.get(path);
    if (data is! Map) {
      throw const ApiException(
        'Chi tiết quản trị trả về không đúng định dạng.',
      );
    }
    final record = AdminRecord(Map<String, dynamic>.from(data));
    if (record.id != id) {
      throw const ApiException('Chi tiết trả về không đúng mã đã yêu cầu.');
    }
    return record;
  }

  Future<void> setStatus(AdminSection section, int id, String status) async {
    _validateId(id);
    if (section == AdminSection.orders || !section.statuses.contains(status)) {
      throw ArgumentError('Trạng thái không hợp lệ.');
    }
    await client.patch('${section.path}/$id/status', body: {'status': status});
  }

  Future<void> setUserRole(int id, String role) async {
    _validateId(id);
    if (!adminRoles.contains(role)) {
      throw ArgumentError('Vai trò không hợp lệ.');
    }
    await client.patch('/admin/users/$id/role', body: {'role': role});
  }

  Future<void> saveCategory({
    int? id,
    required String name,
    required String slug,
    int? parentId,
    int displayOrder = 0,
    AdminUpload? image,
  }) async {
    if (id != null) _validateId(id);
    if (parentId != null) _validateId(parentId);
    if (name.trim().isEmpty || slug.trim().isEmpty || displayOrder < 0) {
      throw ArgumentError('Tên, slug và thứ tự danh mục không hợp lệ.');
    }
    if (id != null && id == parentId) {
      throw ArgumentError('Danh mục không thể là danh mục cha của chính nó.');
    }
    final body = <String, dynamic>{
      'name': name.trim(),
      'slug': slug.trim(),
      'parentId': parentId,
      'displayOrder': displayOrder,
    };
    await _save('/admin/categories', id, _withImage(body, 'image', image));
  }

  Future<void> saveShippingCompany({
    int? id,
    required String name,
    required String code,
    String? phone,
    String? email,
    String? website,
    AdminUpload? logo,
  }) async {
    if (id != null) _validateId(id);
    if (name.trim().isEmpty || code.trim().isEmpty) {
      throw ArgumentError('Tên và mã đơn vị vận chuyển không được để trống.');
    }
    final body = <String, dynamic>{
      'name': name.trim(),
      'code': code.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (email != null) 'email': email.trim(),
      if (website != null) 'website': website.trim(),
    };
    await _save(
      '/admin/shipping-companies',
      id,
      _withImage(body, 'logo', logo),
    );
  }

  Future<void> delete(AdminSection section, int id) async {
    _validateId(id);
    if (!section.supportsEdit) {
      throw ArgumentError('Phân hệ này không hỗ trợ xóa.');
    }
    await client.delete('${section.path}/$id');
  }

  Future<void> cancelOrder(int id, String reason) async {
    _validateId(id);
    if (reason.trim().isEmpty) {
      throw ArgumentError('Vui lòng nhập lý do hủy đơn.');
    }
    await client.put('/orders/$id/cancel', body: {'reason': reason.trim()});
  }

  Future<void> _save(String path, int? id, Object body) async {
    if (id == null) {
      await client.post(path, body: body);
    } else {
      await client.put('$path/$id', body: body);
    }
  }

  Object _withImage(
    Map<String, dynamic> body,
    String field,
    AdminUpload? upload,
  ) {
    if (upload == null) return body;
    if (upload.bytes.isEmpty || upload.fileName.trim().isEmpty) {
      throw ArgumentError('Tệp ảnh không hợp lệ.');
    }
    // Empty multipart parentId represents a root category, not the string
    // "null"; JSON requests retain an actual null.
    return FormData.fromMap({
      ...body,
      field: MultipartFile.fromBytes(upload.bytes, filename: upload.fileName),
    });
  }

  void _validateId(int id) {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'Mã phải lớn hơn 0.');
  }
}
