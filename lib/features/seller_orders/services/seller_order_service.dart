import 'package:dio/dio.dart';

import '../../../config/api_config.dart';

class SellerOrderException implements Exception {
  const SellerOrderException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SellerOrderService {
  SellerOrderService({Dio? dio, String? token})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 30),
            ),
          ),
      _token = token ?? ApiConfig.jwtToken;

  final Dio _dio;
  final String _token;

  Future<Map<String, dynamic>> getOrders({
    required String status,
    required int page,
  }) {
    return _get(
      '/seller/orders',
      query: {'status': status, 'page': page, 'size': 10},
    );
  }

  Future<Map<String, dynamic>> getOrderDetail(int orderId) {
    return _get('/orders/$orderId');
  }

  Future<void> readyToShip(int orderId) async {
    await _request('PUT', '/orders/$orderId/ready-to-ship');
  }

  Future<void> cancelOrder(int orderId, String reason) async {
    await _request(
      'PUT',
      '/seller/orders/$orderId/cancel',
      body: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _request('GET', path, query: query);
    if (response['data'] is! Map) {
      throw const SellerOrderException('Response thiếu dữ liệu đơn hàng.');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  // Dùng chung cách gắn JWT và xử lý lỗi cho GET/PUT; không tự gửi lại PUT.
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    final token = _token.trim();
    if (token.isEmpty) {
      throw const SellerOrderException(
        'Chưa có token Seller. Hãy điền jwtToken trong lib/config/api_config.dart.',
      );
    }

    try {
      final response = await _dio.request<dynamic>(
        path,
        queryParameters: query,
        data: body,
        options: Options(
          method: method,
          contentType: body == null ? null : Headers.jsonContentType,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 204) return {};
      final responseBody = response.data;
      if (responseBody is! Map) {
        throw const SellerOrderException(
          'Dữ liệu backend trả về không đúng định dạng.',
        );
      }
      if (responseBody['status'] != 'success') {
        throw SellerOrderException(
          _message(responseBody) ??
              'Yêu cầu xử lý đơn hàng thất bại. Vui lòng thử lại.',
        );
      }
      return Map<String, dynamic>.from(responseBody);
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      // Luôn có thông báo cho 401/403, kể cả backend trả body rỗng hoặc HTML.
      if (code == 401) {
        throw const SellerOrderException(
          'JWT đã hết hạn hoặc không hợp lệ. Hãy cập nhật token Seller rồi khởi động lại ứng dụng.',
          statusCode: 401,
        );
      }
      if (code == 403) {
        throw const SellerOrderException(
          'Tài khoản không đủ quyền. Hãy sử dụng token có vai trò SELLER và quyền truy cập shop.',
          statusCode: 403,
        );
      }
      if (code == 409) {
        throw SellerOrderException(
          _message(error.response?.data) ?? 'Đơn hàng đã thay đổi hoặc không còn ở trạng thái cho phép. Vui lòng tải lại chi tiết.',
          statusCode: 409,
        );
      }
      if (code != null) {
        throw SellerOrderException(
          _message(error.response?.data) ??
              'Yêu cầu thất bại (HTTP $code). Vui lòng thử lại.',
          statusCode: code,
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const SellerOrderException(
          'Backend phản hồi quá lâu. Vui lòng thử lại.',
        );
      }
      throw const SellerOrderException(
        'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }
  }

  String? _message(dynamic body) {
    if (body is! Map || body['message'] is! String) return null;
    final message = (body['message'] as String).trim();
    return message.isEmpty ? null : message;
  }

  void close() => _dio.close(force: true);
}
