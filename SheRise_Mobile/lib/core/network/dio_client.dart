import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import 'api_endpoints.dart';

class DioClient {
  late final Dio _dio;
  final AuthService _authService;

  DioClient({required AuthService authService}) : _authService = authService {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.addAll([
      _authInterceptor(),
      _loggingInterceptor(),
      _errorInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _authService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final user = await _authService.getUser();
        if (user != null) {
          options.headers['X-User-Id'] = user.id;
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry original request with new token
            final token = await _authService.getToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } else {
            // Refresh failed - clear auth and let caller handle redirect
            await _authService.clearAuth();
          }
        }
        handler.next(error);
      },
    );
  }

  Future<bool> _refreshToken() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await Dio().post(
        '${AppConstants.baseUrl}${ApiEndpoints.refreshToken}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newToken = response.data['token'] as String;
        await _authService.saveToken(newToken);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      return false;
    }
  }

  Interceptor _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('➡️ REQUEST: ${options.method} ${options.path}');
        debugPrint('Headers: ${options.headers}');
        if (options.data != null) debugPrint('Body: ${options.data}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('⬅️ RESPONSE: ${response.statusCode} ${response.requestOptions.path}');
        handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('❌ ERROR: ${error.response?.statusCode} ${error.requestOptions.path}');
        debugPrint('Message: ${error.message}');
        handler.next(error);
      },
    );
  }

  Interceptor _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) {
        String message = 'Something went wrong';
        if (error.response != null) {
          final data = error.response?.data;
          if (data is Map && data['message'] != null) {
            message = data['message'];
          } else if (error.response?.statusCode == 401) {
            message = 'Session expired. Please login again.';
          } else if (error.response?.statusCode == 404) {
            message = 'Resource not found';
          } else if (error.response?.statusCode == 500) {
            message = 'Server error. Please try again later.';
          }
        } else if (error.type == DioExceptionType.connectionTimeout) {
          message = 'Connection timed out. Check your internet.';
        } else if (error.type == DioExceptionType.connectionError) {
          message = 'No internet connection.';
        }
        final customError = error.copyWith(message: message);
        handler.next(customError);
      },
    );
  }
}
