class WorkerModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final List<String> skills;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final String location;
  final int jobsPosted;
  final int jobsApplied;
  final double hourlyRate;

  const WorkerModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.skills,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.location,
    this.jobsPosted = 0,
    this.jobsApplied = 0,
    this.hourlyRate = 150.0,
  });

  factory WorkerModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedSkills = [];
    if (json['skills'] != null) {
      if (json['skills'] is List) {
        parsedSkills = (json['skills'] as List).map((e) => e.toString()).toList();
      } else if (json['skills'] is String) {
        parsedSkills = (json['skills'] as String)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }

    return WorkerModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Skilled Worker',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      skills: parsedSkills,
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 4.8,
      reviewCount: (json['reviewCount'] is num) ? (json['reviewCount'] as num).toInt() : 5,
      isVerified: json['isVerified'] == true,
      location: json['location']?.toString() ?? 'Nearby',
      jobsPosted: (json['jobsPosted'] is num) ? (json['jobsPosted'] as num).toInt() : 0,
      jobsApplied: (json['jobsApplied'] is num) ? (json['jobsApplied'] as num).toInt() : 0,
      hourlyRate: (json['hourlyRate'] is num)
          ? (json['hourlyRate'] as num).toDouble()
          : (json['hourly_rate'] is num)
              ? (json['hourly_rate'] as num).toDouble()
              : 150.0,
    );
  }
}
