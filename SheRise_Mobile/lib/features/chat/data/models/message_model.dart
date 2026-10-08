class MessageModel {
  final String id;
  final String jobId;
  final String senderId;
  final String senderName;
  final String content;
  final String timestamp;
  final bool read;

  MessageModel({
    required this.id,
    required this.jobId,
    required this.senderId,
    this.senderName = '',
    required this.content,
    required this.timestamp,
    this.read = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? json['job_id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? json['sender_id']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? json['sender_name']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      read: json['read'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': jobId,
      'senderId': senderId,
      'content': content,
      'timestamp': timestamp,
      'read': read,
    };
  }
}
