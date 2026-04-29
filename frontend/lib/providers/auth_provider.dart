import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/member.dart';
import 'notice_provider.dart';

import '../services/push_notification_service.dart'; // 💡 FCM 추가

final authProvider = AsyncNotifierProvider<AuthNotifier, Member?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<Member?> {
  @override
  Future<Member?> build() async {
    return _checkLoginStatus();
  }

  Future<void> _sendFcmToken(Dio dio) async {
    try {
      final token = await PushNotificationService().getToken();
      if (token != null) {
        await dio.post('/auth/fcm-token', data: {'fcmToken': token});
        print('FCM Token sent successfully');
      }
    } catch (e) {
      print('Failed to send FCM token to backend: $e');
    }
  }

  Future<Member?> _checkLoginStatus() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/members/me');
      
      // 💡 로그인 상태가 확인되면 FCM 토큰을 서버로 전송
      await _sendFcmToken(dio);

      return Member.fromJson(response.data);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> login(String loginId, String password) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/login', data: {
        'loginId': loginId,
        'password': password,
      });
      final member = await _checkLoginStatus();
      state = AsyncValue.data(member);
    } catch (e) {
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
