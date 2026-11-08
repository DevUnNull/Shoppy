import 'package:dio/dio.dart';

import '../../../config/api_config.dart';

class ShipperOrderException implements Exception {
  const ShipperOrderException(
    this.message, {
    this.statusCode,
    this.isTimeout = false,
    this.isRejected = false,
  });
  final String message;
  final int? statusCode;
  final bool isTimeout;
  final bool isRejected;
  @override
  String toString() => message;
}

class ShipperOrderService {
  ShipperOrderService({Dio? dio, String? token})
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
      _token = token ?? '';
  final Dio _dio;
  final String _token;

  Future<dynamic> getAvailableOrders() =>
      _request('GET', '/shipper/orders/available');
  Future<dynamic> getOrderDetail(int id) =>
      _request('GET', '/shipper/orders/$id');
  Future<dynamic> getMyDeliveries({String status = 'SHIPPING'}) => _request(
    'GET',
    '/shipper/orders/my-deliveries',
    query: {'status': status},
  );
  Future<void> assign(int id) async {
    await _request('PUT', '/shipper/orders/$id/assign');
  }

  Future<void> delivered(int id) async {
    await _request('PUT', '/shipper/orders/$id/delivered');
  }

  Future<dynamic> getCodBalance() => _request('GET', '/shipper/cod/balance');
  Future<dynamic> getCodTransactions({String? type}) => _request(
    'GET',
    '/shipper/cod/transactions',
    query: type == null ? null : {'type': type},
  );
  Future<dynamic> remitCod(int amount, String note) => _request(
    'POST',
    '/shipper/cod/remittance',
    body: {'amount': amount, 'note': note},
  );

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    if (_token.trim().isEmpty) {
      throw const ShipperOrderException(
        'Vui lòng đăng nhập tài khoản Shipper để sử dụng chức năng giao hàng và COD.',
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
            'Authorization': 'Bearer ${_token.trim()}',
          },
        ),
      );
      if ((method == 'PUT' || method == 'POST') && response.statusCode == 204) {
        return null;
      }
      final responseBody = response.data;
      if (responseBody is! Map || responseBody['status'] != 'success') {
        throw ShipperOrderException(
          _message(responseBody) ?? 'Yêu cầu thất bại. Vui lòng thử lại.',
          isRejected: responseBody is Map && responseBody['status'] == 'error',
        );
      }
      return responseBody['data'];
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      if (code == 401) {
        throw const ShipperOrderException(
          'Phiên đăng nhập đã hết hạn hoặc không hợp lệ. Vui lòng đăng nhập lại.',
          statusCode: 401,
        );
      }
      if (code == 403) {
        throw const ShipperOrderException(
          'Tài khoản không đủ quyền thực hiện thao tác. Cần tài khoản SHIPPER có quyền truy cập.',
          statusCode: 403,
        );
      }
      if (code == 409) {
        throw ShipperOrderException(
          _message(error.response?.data) ??
              'Đơn hàng đã được xử lý hoặc đã đổi trạng thái.',
          statusCode: 409,
        );
      }
      if (code != null) {
        throw ShipperOrderException(
          _message(error.response?.data) ??
              'Yêu cầu thất bại (HTTP $code). Vui lòng thử lại.',
          statusCode: code,
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const ShipperOrderException(
          'Yêu cầu quá thời gian chờ. Cần tải lại dữ liệu và kiểm tra trạng thái trước khi thử lại.',
          isTimeout: true,
        );
      }
      throw const ShipperOrderException(
        'Không kết nối được máy chủ. Kiểm tra mạng hoặc cấu hình CORS nếu chạy trên trình duyệt.',
      );
    }
  }

  String? _message(dynamic data) {
    if (data is! Map || data['message'] is! String) return null;
    final message = (data['message'] as String).trim();
    return message.isEmpty ? null : message;
  }

  void close() => _dio.close(force: true);
}
