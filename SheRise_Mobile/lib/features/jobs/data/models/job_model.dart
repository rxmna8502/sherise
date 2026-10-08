class JobModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final int minAmount;
  final int maxAmount;
  final String location;
  final String deliveryType;
  final String urgency;
  final String customerName;
  final double customerRating;
  final String postedAt;
  final String status;
  final String? creatorId;
  final String? workerId;
  final int applicationsCount;
  final String? myApplicationStatus;

  JobModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.minAmount,
    required this.maxAmount,
    this.location = 'Online',
    this.deliveryType = 'pickup',
    this.urgency = 'flexible',
    this.customerName = 'Anonymous',
    this.customerRating = 5.0,
    required this.postedAt,
    this.status = 'open',
    this.creatorId,
    this.workerId,
    this.applicationsCount = 0,
    this.myApplicationStatus,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    int parseAmount(dynamic val) {
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    final amountMap = json['amount'] as Map<String, dynamic>?;
    final minAmt = json['min_amount'] != null
        ? parseAmount(json['min_amount'])
        : (amountMap != null ? parseAmount(amountMap['min']) : 0);
    final maxAmt = json['max_amount'] != null
        ? parseAmount(json['max_amount'])
        : (amountMap != null ? parseAmount(amountMap['max']) : minAmt);

    return JobModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Work',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Other',
      minAmount: minAmt,
      maxAmount: maxAmt,
      location: json['location']?.toString() ?? 'Local',
      deliveryType: json['deliveryType']?.toString() ?? 'pickup',
      urgency: json['urgency']?.toString() ?? 'flexible',
      customerName: json['customerName']?.toString() ?? 'Customer',
      customerRating: (json['customerRating'] as num?)?.toDouble() ?? 5.0,
      postedAt: json['postedAt']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      creatorId: json['creator_id']?.toString() ?? json['creatorId']?.toString(),
      workerId: json['worker_id']?.toString() ?? json['workerId']?.toString(),
      applicationsCount: (json['applications'] as List?)?.length ?? 0,
      myApplicationStatus: json['myApplicationStatus']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'amount': {'min': minAmount, 'max': maxAmount},
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'location': location,
      'deliveryType': deliveryType,
      'urgency': urgency,
      'customerName': customerName,
      'customerRating': customerRating,
      'postedAt': postedAt,
      'status': status,
      'creator_id': creatorId,
      'worker_id': workerId,
    };
  }
}
