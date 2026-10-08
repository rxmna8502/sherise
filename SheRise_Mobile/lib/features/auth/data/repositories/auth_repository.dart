import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/user_model.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository({required Dio dio}) : _dio = dio;

  Future<Map<String, dynamic>> login({
    required String email,
    required String phone,
    required String name,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: {
        'email': email,
        'phone': phone,
        'name': name,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendOtp({
    required String email,
    String? phone,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.sendOtp,
      data: {
        'email': email,
        if (phone != null) 'phone': phone,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendOtpRegister({
    required String email,
    String? phone,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.sendOtpRegister,
      data: {
        'email': email,
        if (phone != null) 'phone': phone,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    String? phone,
    required String otp,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.verifyOtp,
      data: {
        'email': email,
        if (phone != null) 'phone': phone,
        'otp': otp,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String gender,
    List<String>? skills,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.register,
      data: {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'gender': gender,
        if (skills != null) 'skills': skills,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<UserModel?> getMe() async {
    final response = await _dio.get(ApiEndpoints.me);
    if (response.data['success'] == true) {
      return UserModel.fromJson(response.data['user']);
    }
    return null;
  }
}
