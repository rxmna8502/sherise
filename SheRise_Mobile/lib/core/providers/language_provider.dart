import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../network/api_endpoints.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class LanguageInfo {
  final String code;
  final String name;
  final String nativeName;
  final String scriptSample;

  const LanguageInfo({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.scriptSample,
  });
}

const List<LanguageInfo> kSupportedLanguages = [
  LanguageInfo(code: 'en', name: 'English', nativeName: 'English', scriptSample: 'Hello'),
  LanguageInfo(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', scriptSample: 'नमस्ते'),
  LanguageInfo(code: 'te', name: 'Telugu', nativeName: 'తెలుగు', scriptSample: 'నమస్కారం'),
  LanguageInfo(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', scriptSample: 'வணக்கம்'),
  LanguageInfo(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', scriptSample: 'ನಮಸ್ಕಾರ'),
  LanguageInfo(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', scriptSample: 'നമസ്കാരം'),
  LanguageInfo(code: 'mr', name: 'Marathi', nativeName: 'मराठी', scriptSample: 'नमस्कार'),
  LanguageInfo(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', scriptSample: 'নমস্কার'),
  LanguageInfo(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', scriptSample: 'નમસ્તે'),
  LanguageInfo(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', scriptSample: 'ਸਤਿ ਸ਼੍ਰੀ ਅਕਾਲ'),
];

class LanguageState {
  final LanguageInfo currentLanguage;
  final bool isTranslating;

  const LanguageState({
    required this.currentLanguage,
    this.isTranslating = false,
  });

  LanguageState copyWith({
    LanguageInfo? currentLanguage,
    bool? isTranslating,
  }) {
    return LanguageState(
      currentLanguage: currentLanguage ?? this.currentLanguage,
      isTranslating: isTranslating ?? this.isTranslating,
    );
  }
}

class LanguageNotifier extends StateNotifier<LanguageState> {
  final Dio _dio;

  LanguageNotifier({required Dio dio})
      : _dio = dio,
        super(LanguageState(currentLanguage: kSupportedLanguages[0]));

  void setLanguage(LanguageInfo language) {
    state = state.copyWith(currentLanguage: language);
  }

  Future<String> translateText(String text) async {
    if (state.currentLanguage.code == 'en') return text;
    try {
      final response = await _dio.post(
        ApiEndpoints.translate,
        data: {
          'text': text,
          'targetLang': state.currentLanguage.code,
        },
      );
      if (response.data is Map && response.data['translatedText'] != null) {
        return response.data['translatedText'] as String;
      }
    } catch (_) {}
    return text;
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, LanguageState>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return LanguageNotifier(dio: dioClient.dio);
});
