import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/models/user.dart';
import '../core/secure_storage.dart';

class AuthState {
  final AppUser? user;
  final bool loading;
  final Showroom? showroom;

  const AuthState({this.user, this.loading = true, this.showroom});

  AuthState copyWith({AppUser? user, bool? loading, Showroom? showroom, bool clearShowroom = false}) =>
      AuthState(
        user: user ?? this.user,
        loading: loading ?? this.loading,
        showroom: clearShowroom ? null : (showroom ?? this.showroom),
      );

  bool get isLoggedIn => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _restore();
  }

  Future<void> _restore() async {
    final token = await TokenStorage.readAccess();
    if (token == null) {
      state = state.copyWith(loading: false);
      return;
    }
    try {
      final res = await ApiClient.instance.dio.get('/me');
      state = state.copyWith(user: AppUser.fromJson(res.data), loading: false);
      await refreshShowroom();
    } catch (_) {
      await TokenStorage.clear();
      state = state.copyWith(loading: false);
    }
  }

  /// Returns the OTP code when the backend hands it back directly (dev/test
  /// only, no real SMS provider configured) — null once Sparrow SMS is on.
  Future<String?> requestOtp(String phone) async {
    final res = await ApiClient.instance.dio.post('/auth/otp/request', data: {'phone': phone});
    return res.data['devCode'] as String?;
  }

  Future<void> verifyOtp(String phone, String code) async {
    final res = await ApiClient.instance.dio.post('/auth/otp/verify', data: {'phone': phone, 'code': code});
    await TokenStorage.save(res.data['accessToken'], res.data['refreshToken']);
    state = state.copyWith(user: AppUser.fromJson(res.data['user']), loading: false);
    await refreshShowroom();
  }

  Future<void> registerWithEmail(String email, String password, String? name) async {
    final res = await ApiClient.instance.dio.post('/auth/email/register', data: {
      'email': email,
      'password': password,
      if (name != null && name.isNotEmpty) 'name': name,
    });
    await TokenStorage.save(res.data['accessToken'], res.data['refreshToken']);
    state = state.copyWith(user: AppUser.fromJson(res.data['user']), loading: false);
    await refreshShowroom();
  }

  Future<void> loginWithEmail(String email, String password) async {
    final res = await ApiClient.instance.dio
        .post('/auth/email/login', data: {'email': email, 'password': password});
    await TokenStorage.save(res.data['accessToken'], res.data['refreshToken']);
    state = state.copyWith(user: AppUser.fromJson(res.data['user']), loading: false);
    await refreshShowroom();
  }

  /// Returns the reset code when the backend hands it back directly
  /// (dev/test only, no real email provider configured).
  Future<String?> forgotPassword(String email) async {
    final res = await ApiClient.instance.dio.post('/auth/email/forgot-password', data: {'email': email});
    return res.data['devCode'] as String?;
  }

  Future<void> resetPassword(String email, String code, String newPassword) async {
    await ApiClient.instance.dio.post('/auth/email/reset-password', data: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<void> refreshShowroom() async {
    try {
      final res = await ApiClient.instance.dio.get('/showrooms/mine');
      if (res.data != null) {
        state = state.copyWith(showroom: Showroom.fromJson(res.data));
      }
    } catch (_) {
      // No showroom yet — fine, the UI prompts the user to create/join one.
    }
  }

  Future<void> createShowroom(String name) async {
    final res = await ApiClient.instance.dio.post('/showrooms', data: {'name': name});
    state = state.copyWith(showroom: Showroom.fromJson(res.data));
    await _refetchMe();
  }

  Future<void> joinShowroom(String joinCode) async {
    await ApiClient.instance.dio.post('/showrooms/join', data: {'joinCode': joinCode});
    await refreshShowroom();
    await _refetchMe();
  }

  Future<void> _refetchMe() async {
    final res = await ApiClient.instance.dio.get('/me');
    state = state.copyWith(user: AppUser.fromJson(res.data));
  }

  Future<void> setAvailable(bool available) async {
    final res = await ApiClient.instance.dio.patch('/me', data: {'isAvailable': available});
    state = state.copyWith(user: AppUser.fromJson(res.data));
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    state = const AuthState(loading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
