import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    super.address,
    super.aadhaarLast4,
    super.gender,
    super.credits,
    super.rating,
    super.reviewCount,
    super.isVerified,
    super.aadhaarVerified,
    super.availability,
    super.skills,
    super.portfolio,
    super.workHistory,
    super.isOnline,
    super.lastSeen,
    super.latitude,
    super.longitude,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      aadhaarLast4: json['aadhaarLast4']?.toString(),
      gender: json['gender']?.toString(),
      credits: json['credits'] ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] ?? 0,
      isVerified: json['isVerified'] ?? true,
      aadhaarVerified: json['aadhaarVerified'] ?? false,
      availability: json['availability']?.toString(),
      skills: _parseList(json['skills']),
      portfolio: _parseList(json['portfolio']),
      workHistory: _parseList(json['workHistory']),
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'aadhaarLast4': aadhaarLast4,
      'gender': gender,
      'credits': credits,
      'rating': rating,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'aadhaarVerified': aadhaarVerified,
      'availability': availability,
      'skills': skills,
      'portfolio': portfolio,
      'workHistory': workHistory,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}
