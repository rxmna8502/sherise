import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../services/auth_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final dioClientProvider = Provider<DioClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  return DioClient(authService: authService);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRepository(dio: dioClient.dio);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(repository: repository, authService: authService);
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final AuthService _authService;

  AuthNotifier({
    required AuthRepository repository,
    required AuthService authService,
  })  : _repository = repository,
        _authService = authService,
        super(const AuthState());

  Future<void> checkAuth() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      final user = await _authService.getUser();
      if (user != null) {
        state = state.copyWith(user: user, isAuthenticated: true);
        return;
      }
    }
    state = state.copyWith(isAuthenticated: false);
  }

  Future<void> login({
    required String email,
    required String phone,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.login(
        email: email,
        phone: phone,
        name: name,
      );

      if (result['success'] == true) {
        final token = result['token'] as String;
        final user = UserModel.fromJson(result['user']);
        await _authService.saveToken(token);
        await _authService.saveUser(user);
        state = state.copyWith(
          user: user,
          isLoading: false,
          isAuthenticated: true,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message']?.toString() ?? 'Login failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> sendOtp({
    required String email,
    String? phone,
    bool isRegister = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = isRegister
          ? await _repository.sendOtpRegister(email: email, phone: phone)
          : await _repository.sendOtp(email: email, phone: phone);

      state = state.copyWith(isLoading: false);
      if (result['success'] == true) {
        return true;
      } else {
        state = state.copyWith(error: result['message']?.toString());
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> sendOtpRegister({
    required String email,
    String? phone,
  }) async {
    return sendOtp(email: email, phone: phone, isRegister: true);
  }

  Future<bool> verifyOtp({
    required String email,
    String? phone,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.verifyOtp(
        email: email,
        phone: phone,
        otp: otp,
      );

      if (result['success'] == true && result['token'] != null) {
        final token = result['token'] as String;
        final user = UserModel.fromJson(result['user']);
        await _authService.saveToken(token);
        await _authService.saveUser(user);
        state = state.copyWith(
          user: user,
          isLoading: false,
          isAuthenticated: true,
          error: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message']?.toString() ?? 'Verification failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String gender,
    List<String>? skills,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.register(
        name: name,
        email: email,
        phone: phone,
        address: address,
        gender: gender,
        skills: skills,
      );

      state = state.copyWith(isLoading: false);
      if (result['success'] == true) {
        return true;
      } else {
        state = state.copyWith(error: result['message']?.toString());
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.clearAuth();
    state = const AuthState();
  }
}
