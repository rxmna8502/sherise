import 'package:flutter_test/flutter_test.dart';
import 'package:sherise_mobile/features/jobs/data/models/job_model.dart';
import 'package:sherise_mobile/features/chat/data/models/message_model.dart';
import 'package:sherise_mobile/features/notifications/data/models/notification_model.dart';
import 'package:sherise_mobile/features/jobs/data/models/worker_model.dart';
import 'package:sherise_mobile/features/profile/data/models/subscription_model.dart';

void main() {
  group('SheRise Mobile Native Models Tests', () {
    test('JobModel parses JSON properly', () {
      final json = {
        'id': 'j-101',
        'title': 'Tailoring Silk Saree Blouse',
        'description': 'Need stitching by Saturday',
        'category': 'Tailoring',
        'amount': {'min': 400, 'max': 900},
        'location': 'Hyderabad',
        'deliveryType': 'pickup',
        'urgency': 'urgent',
        'customerName': 'Lakshmi',
        'customerRating': 4.9,
        'postedAt': '2026-10-08 10:00 AM',
        'status': 'open',
      };

      final job = JobModel.fromJson(json);
      expect(job.id, 'j-101');
      expect(job.title, 'Tailoring Silk Saree Blouse');
      expect(job.category, 'Tailoring');
      expect(job.minAmount, 400);
      expect(job.maxAmount, 900);
      expect(job.urgency, 'urgent');
      expect(job.customerName, 'Lakshmi');
    });

    test('MessageModel serializes and deserializes', () {
      final json = {
        'id': 'm-202',
        'jobId': 'j-101',
        'senderId': 'u-303',
        'senderName': 'Ananya',
        'content': 'I can finish this by Friday evening!',
        'timestamp': '12:45 PM',
        'read': false,
      };

      final msg = MessageModel.fromJson(json);
      expect(msg.id, 'm-202');
      expect(msg.senderName, 'Ananya');
      expect(msg.content, 'I can finish this by Friday evening!');
      expect(msg.read, false);
    });

    test('NotificationModel parses JSON properly', () {
      final json = {
        'id': 'notif-1',
        'userId': 'u-303',
        'type': 'accept',
        'message': 'Your application was accepted!',
        'timestamp': 'Just now',
        'read': false,
      };

      final notif = NotificationModel.fromJson(json);
      expect(notif.id, 'notif-1');
      expect(notif.type, 'accept');
      expect(notif.message, 'Your application was accepted!');
      expect(notif.read, false);
    });

    test('WorkerModel parses JSON properly with skills and ratings', () {
      final json = {
        'id': 'w-505',
        'name': 'Sunita Devi',
        'email': 'sunita@example.com',
        'skills': ['Tailoring', 'Embroidery'],
        'rating': 4.9,
        'reviewCount': 14,
        'isVerified': true,
        'location': 'Kukatpally, Hyderabad',
        'jobsPosted': 2,
        'jobsApplied': 8,
      };

      final worker = WorkerModel.fromJson(json);
      expect(worker.id, 'w-505');
      expect(worker.name, 'Sunita Devi');
      expect(worker.skills.length, 2);
      expect(worker.isVerified, true);
      expect(worker.rating, 4.9);
      expect(worker.location, 'Kukatpally, Hyderabad');
    });

    test('SubscriptionModel parses subscription tiers correctly', () {
      final json = {
        'plan': 'starter',
        'planName': 'Starter Shakti',
        'price': 99,
        'status': 'active',
        'creditsMonthly': 50,
        'features': ['50 Work Credits', 'Verified Badge Boost'],
      };

      final sub = SubscriptionModel.fromJson(json);
      expect(sub.plan, 'starter');
      expect(sub.planName, 'Starter Shakti');
      expect(sub.price, 99);
      expect(sub.creditsMonthly, 50);
      expect(sub.features.length, 2);
    });
  });
}
