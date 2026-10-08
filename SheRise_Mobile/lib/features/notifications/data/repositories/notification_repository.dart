import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final Dio _dio;

  NotificationRepository({required Dio dio}) : _dio = dio;

  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.notifications,
        queryParameters: {'userId': userId},
      );
      if (response.data is List) {
        return (response.data as List)
            .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> markRead(String notificationId) async {
    try {
      final response = await _dio.post('${ApiEndpoints.notifications}/$notificationId/read');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllRead(String userId) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.notifications}/mark-all-read',
        data: {'userId': userId},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
