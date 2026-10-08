class AppConstants {
  // Override with --dart-define=SHE_RISE_URL=... for a physical device or production.
  static const String baseUrl = String.fromEnvironment(
    'SHE_RISE_URL',
    defaultValue: 'http://127.0.0.1:10202',
  );
  static const String frontendUrl = baseUrl;

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
