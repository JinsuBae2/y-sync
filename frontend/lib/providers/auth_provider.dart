import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/member.dart';
import 'notice_provider.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, Member?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<Member?> {
  @override
  Future<Member?> build() async {
    return _checkLoginStatus();
  }

  Future<Member?> _checkLoginStatus() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/members/me');
      return Member.fromJson(response.data);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> login(String loginId, String password) async {
    state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/login', data: {
        'loginId': loginId,
        'password': password,
      });
      final member = await _checkLoginStatus();
      state = AsyncValue.data(member);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> signup(String loginId, String password, String name) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/signup', data: {
        'loginId': loginId,
        'password': password,
        'name': name,
      });
      // Optionally login automatically here, or return to login screen
      // We will handle return to login screen on the UI level
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/logout');
      state = const AsyncValue.data(null);
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }
}
