import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/job_model.dart';
import '../models/worker_model.dart';
import '../../../profile/data/models/subscription_model.dart';

class JobRepository {
  final Dio _dio;

  JobRepository({required Dio dio}) : _dio = dio;

  Future<List<JobModel>> getJobs() async {
    try {
      final response = await _dio.get(ApiEndpoints.jobs);
      if (response.data is List) {
        return (response.data as List)
            .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<JobModel>> getRecommendedJobs() async {
    try {
      final response = await _dio.get('/api/jobs/recommended');
      if (response.data is List) {
        return (response.data as List)
            .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return await getJobs();
    } catch (_) {
      return await getJobs();
    }
  }

  Future<List<WorkerModel>> getNearbyWorkers() async {
    try {
      final response = await _dio.get(ApiEndpoints.nearbyWorkers);
      if (response.data is Map && response.data['workers'] is List) {
        return (response.data['workers'] as List)
            .map((w) => WorkerModel.fromJson(w as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> applyJob({required String jobId, required String workerId}) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.jobs}/$jobId/apply',
        data: {'workerId': workerId},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<JobModel?> createJob({
    required String title,
    required String category,
    required String description,
    required int minAmount,
    required int maxAmount,
    required String location,
    required String deliveryType,
    required String urgency,
    required String customerName,
    required String creatorId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.jobs,
        data: {
          'title': title,
          'category': category,
          'description': description,
          'amount': {'min': minAmount, 'max': maxAmount},
          'location': location,
          'deliveryType': deliveryType,
          'urgency': urgency,
          'customerName': customerName,
          'creatorId': creatorId,
          'paymentMode': 'online',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map && data['job'] != null) {
          return JobModel.fromJson(data['job']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<JobModel>> getMyApplications(String userId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.myApplications,
        data: {'userId': userId},
      );
      if (response.data is List) {
        return (response.data as List)
            .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<JobModel>> getMyPostings(String userId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.myPostings,
        data: {'userId': userId},
      );
      if (response.data is List) {
        return (response.data as List)
            .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> acceptApplication(String appId) async {
    try {
      final response = await _dio.post('/api/applications/$appId/accept');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejectApplication(String appId) async {
    try {
      final response = await _dio.post('/api/applications/$appId/reject');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> completeJob({
    required String jobId,
    required double rating,
    String feedback = '',
  }) async {
    try {
      final response = await _dio.post(
        '/api/jobs/$jobId/complete',
        data: {
          'rating': rating,
          'feedback': feedback,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> analyzeImage(String imagePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath),
      });
      final response = await _dio.post(
        ApiEndpoints.analyzeImage,
        data: formData,
      );
      if (response.data is Map && response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> voiceToText(String audioPath, {String targetLang = 'en'}) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(audioPath),
        'targetLang': targetLang,
      });
      final response = await _dio.post(
        ApiEndpoints.voiceToText,
        data: formData,
      );
      if (response.data is Map && response.data['text'] != null) {
        return response.data['text'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<SubscriptionModel?> getSubscription() async {
    try {
      final response = await _dio.get(ApiEndpoints.subscription);
      if (response.data is Map && response.data['subscription'] != null) {
        return SubscriptionModel.fromJson(response.data['subscription']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> subscribePlan(String plan) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.subscribe,
        data: {'plan': plan},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
