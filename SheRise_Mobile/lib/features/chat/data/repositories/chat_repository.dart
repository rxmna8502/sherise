import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/message_model.dart';

class ChatRepository {
  final Dio _dio;

  ChatRepository({required Dio dio}) : _dio = dio;

  Future<List<MessageModel>> getMessages(String jobId) async {
    try {
      final response = await _dio.get('${ApiEndpoints.messages}/$jobId');
      if (response.data is List) {
        return (response.data as List)
            .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> sendMessage({
    required String jobId,
    required String senderId,
    required String content,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.messages,
        data: {
          'jobId': jobId,
          'senderId': senderId,
          'content': content,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
