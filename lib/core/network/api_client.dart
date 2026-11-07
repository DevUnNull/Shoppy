import 'package:dio/dio.dart';

import '../../config/api_config.dart';
import 'api_exception.dart';

typedef TokenReader = String? Function();

/// Axios-like client dùng chung cho phân hệ Customer.
///
/// - Tự đính kèm `Authorization: Bearer <token>` khi người dùng đã đăng nhập.
/// - Bóc lớp vỏ `{status, message, data}` của backend và trả về `data`.
/// - Chuẩn hoá mọi lỗi thành [ApiException] có thông báo tiếng Việt.
class ApiClient {
  ApiClient({Dio? dio, required TokenReader readToken})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              // Render free tier có thể mất ~50s để "thức dậy".
              connectTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 60),
              headers: {'Accept': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = readToken()?.trim();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        queryParameters: query,
        data: body,
        options: Options(
          method: method,
          contentType: body is FormData
              ? Headers.multipartFormDataContentType
              : (body == null ? null : Headers.jsonContentType),
        ),
      );
      final payload = response.data;
      if (response.statusCode == 204 || payload == null || payload == '') {
        return null;
      }
      if (payload is! Map) {
        throw const ApiException(
          'Dữ liệu máy chủ trả về không đúng định dạng.',
        );
      }
      if (payload['status'] != null && payload['status'] != 'success') {
        throw ApiException(
          _message(payload) ?? 'Yêu cầu thất bại. Vui lòng thử lại.',
          statusCode: response.statusCode,
        );
      }
      return payload['data'];
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  ApiException _mapError(DioException error) {
    final code = error.response?.statusCode;
    final serverMessage = _message(error.response?.data);
    if (code != null) {
      if (serverMessage != null) {
        return ApiException(serverMessage, statusCode: code);
      }
      return ApiException(switch (code) {
        401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        403 => 'Bạn không có quyền thực hiện thao tác này.',
        404 => 'Không tìm thấy dữ liệu yêu cầu.',
        >= 500 => 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
        _ => 'Yêu cầu thất bại (HTTP $code). Vui lòng thử lại.',
      }, statusCode: code);
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(
        'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
      ),
      DioExceptionType.cancel => const ApiException('Yêu cầu đã bị huỷ.'),
      _ => const ApiException(
        'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      ),
    };
  }

  String? _message(dynamic body) {
    if (body is! Map || body['message'] is! String) return null;
    final message = (body['message'] as String).trim();
    return message.isEmpty ? null : message;
  }

  void close() => _dio.close(force: true);
}
