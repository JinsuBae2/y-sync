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
      final storage = ref.read(secureStorageProvider);
      final token = await storage.read(key: 'jwt_token');
      
      if (token == null) return null;

      final dio = ref.read(dioProvider);
      final response = await dio.get('/members/me');
      
      // 💡 로그인 상태가 확인되면 FCM 토큰을 서버로 전송
      await _sendFcmToken(dio);

      return Member.fromJson(response.data);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        // 토큰 만료 등
        final storage = ref.read(secureStorageProvider);
        await storage.delete(key: 'jwt_token');
        return null;
      }
      rethrow;
    }
  }

  Future<void> login(String loginId, String password) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/auth/login', data: {
        'loginId': loginId,
        'password': password,
      });
      
      final token = response.data['token'];
      if (token != null) {
        final storage = ref.read(secureStorageProvider);
        await storage.write(key: 'jwt_token', value: token);
      }

      final member = await _checkLoginStatus();
      state = AsyncValue.data(member);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> socialLogin(String accessToken, String provider) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/auth/social-login', data: {
        'accessToken': accessToken,
        'provider': provider,
      });

      if (response.statusCode == 200) {
        final token = response.data['token'];
        if (token != null) {
          final storage = ref.read(secureStorageProvider);
          await storage.write(key: 'jwt_token', value: token);
        }
        final member = await _checkLoginStatus();
        state = AsyncValue.data(member);
        return null; // 바로 로그인 성공
      } else if (response.statusCode == 202) {
        // 미가입자 -> 추가 정보 필요
        return response.data; // socialId, provider 포함
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> socialSignup(String loginId, String name, String socialId, String provider, {String? password}) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/auth/social-signup', data: {
        'loginId': loginId,
        'name': name,
        'socialId': socialId,
        'provider': provider,
        if (password != null) 'password': password,
      });

      final token = response.data['token'];
      if (token != null) {
        final storage = ref.read(secureStorageProvider);
        await storage.write(key: 'jwt_token', value: token);
      }
      final member = await _checkLoginStatus();
      state = AsyncValue.data(member);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400 && e.response?.data['message'] == 'REQUIRE_PASSWORD') {
        throw Exception('REQUIRE_PASSWORD');
      }
      if (e is DioException && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
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
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      final storage = ref.read(secureStorageProvider);
      await storage.delete(key: 'jwt_token');
      
      final dio = ref.read(dioProvider);
      await dio.post('/auth/logout');
      
      state = const AsyncValue.data(null);
    } catch (e) {
      final storage = ref.read(secureStorageProvider);
      await storage.delete(key: 'jwt_token');
      state = const AsyncValue.data(null);
    }
  }
}
