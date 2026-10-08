class ApiEndpoints {
  static const String base = '/api';

  // Auth
  static const String login = '$base/login';
  static const String sendOtp = '$base/send-otp';
  static const String sendOtpRegister = '$base/send-otp-register';
  static const String verifyOtp = '$base/verify-otp';
  static const String register = '$base/register';
  static const String refreshToken = '$base/refresh-token';

  // User
  static const String me = '$base/users/me';
  static const String meStatus = '$base/users/me/status';
  static const String updateLocation = '$base/users/me/location';

  // Jobs
  static const String jobs = '$base/jobs';
  static const String recommendedJobs = '$base/jobs/recommended';
  static const String myPostings = '$base/my-postings';
  static const String myApplications = '$base/my-applications';
  static const String trendingSkills = '$base/skills/trending';
  static const String extractSkills = '$base/users/extract-skills';

  // Messages
  static const String messages = '$base/messages';

  // Notifications
  static const String notifications = '$base/notifications';
  static const String notificationCount = '$base/notifications/count';

  // DigiLocker
  static const String digilockerAuth = '$base/digilocker/auth-url';
  static const String digilockerVerify = '$base/digilocker/verify';
  static const String digilockerStatus = '$base/digilocker/status';

  // Nearby Workers
  static const String nearbyWorkers = '$base/workers/nearby';

  // AI & Voice
  static const String voiceToText = '$base/voice-to-text';
  static const String analyzeImage = '$base/analyze-image';
  static const String translate = '$base/translate';
  static const String transliterate = '$base/transliterate';

  // Subscriptions & Plans
  static const String subscription = '$base/subscription';
  static const String subscribe = '$base/subscription/subscribe';

  // Safety & Emergency
  static const String sosTrigger = '$base/sos/trigger';
  static const String safetyReports = '$base/safety-reports';
}
