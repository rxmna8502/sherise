class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String message;
  final String timestamp;
  final bool read;

  NotificationModel({
    required this.id,
    required this.userId,
    this.type = 'info',
    required this.message,
    required this.timestamp,
    this.read = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'info',
      message: json['message']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      read: json['read'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'message': message,
      'timestamp': timestamp,
      'read': read,
    };
  }
}
