import 'package:dio/dio.dart';

class SafetyRepository {
  final Dio _dio;

  SafetyRepository({required Dio dio}) : _dio = dio;

  Future<bool> triggerSos({
    required double latitude,
    required double longitude,
    String? note,
  }) async {
    try {
      final response = await _dio.post(
        '/api/safety/sos',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'note': note ?? 'Emergency SOS triggered from SheRise Mobile App',
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitReport({
    required String reportType,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.post(
        '/api/safety-reports',
        data: {
          'report_type': reportType,
          'description': description,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
