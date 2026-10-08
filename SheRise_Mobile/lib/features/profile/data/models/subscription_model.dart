class SubscriptionModel {
  final String plan;
  final String planName;
  final int price;
  final String status;
  final int creditsMonthly;
  final List<String> features;

  const SubscriptionModel({
    required this.plan,
    required this.planName,
    required this.price,
    required this.status,
    required this.creditsMonthly,
    required this.features,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      plan: json['plan']?.toString() ?? 'free',
      planName: json['planName']?.toString() ?? 'Free Starter',
      price: (json['price'] is num) ? (json['price'] as num).toInt() : 0,
      status: json['status']?.toString() ?? 'active',
      creditsMonthly: (json['creditsMonthly'] is num) ? (json['creditsMonthly'] as num).toInt() : 10,
      features: (json['features'] is List)
          ? (json['features'] as List).map((f) => f.toString()).toList()
          : [
              '10 Monthly Work Credits',
              'Community Job Applications',
              'Standard In-App Chat',
            ],
    );
  }
}
