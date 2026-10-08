class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String? aadhaarLast4;
  final String? gender;
  final int credits;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool aadhaarVerified;
  final String? availability;
  final List<String> skills;
  final List<dynamic> portfolio;
  final List<dynamic> workHistory;
  final bool isOnline;
  final String? lastSeen;
  final double? latitude;
  final double? longitude;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    this.aadhaarLast4,
    this.gender,
    this.credits = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isVerified = true,
    this.aadhaarVerified = false,
    this.availability,
    this.skills = const [],
    this.portfolio = const [],
    this.workHistory = const [],
    this.isOnline = false,
    this.lastSeen,
    this.latitude,
    this.longitude,
  });
}
