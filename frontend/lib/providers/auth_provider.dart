import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/member.dart';
import 'notice_provider.dart';
import 'mypage_provider.dart';
import 'community_provider.dart';

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
      final response = await dio.post(
        '/auth/login',
        data: {'loginId': loginId, 'password': password},
      );

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

  Future<Map<String, dynamic>?> socialLogin(
    String accessToken,
    String provider,
  ) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/social-login',
        data: {'accessToken': accessToken, 'provider': provider},
      );

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
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      rethrow;
    }
  }

  Future<void> socialSignup(
    String loginId,
    String name,
    String socialId,
    String provider, {
    String? password,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/social-signup',
        data: {
          'loginId': loginId,
          'name': name,
          'socialId': socialId,
          'provider': provider,
          if (password != null) 'password': password,
        },
      );

      final token = response.data['token'];
      if (token != null) {
        final storage = ref.read(secureStorageProvider);
        await storage.write(key: 'jwt_token', value: token);
      }
      final member = await _checkLoginStatus();
      state = AsyncValue.data(member);
    } catch (e) {
      if (e is DioException &&
          e.response?.statusCode == 400 &&
          e.response?.data['message'] == 'REQUIRE_PASSWORD') {
        throw Exception('REQUIRE_PASSWORD');
      }
      if (e is DioException && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      rethrow;
    }
  }

  Future<void> verifyStudent(String loginId, String name) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/auth/verify-student',
        data: {'loginId': loginId, 'name': name},
      );
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      rethrow;
    }
  }

  Future<void> sendVerificationCode(
    String loginId,
    String name,
    String email,
  ) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/auth/verify-student/send-code',
        data: {'loginId': loginId, 'name': name, 'email': email},
      );
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      rethrow;
    }
  }

  Future<bool> verifyCode(String loginId, String code) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/verify-student/verify-code',
        data: {'loginId': loginId, 'code': code},
      );
      return response.data['success'] ?? false;
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      rethrow;
    }
  }

  Future<bool> checkDuplicate(String loginId) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/auth/check-duplicate',
        queryParameters: {'loginId': loginId},
      );
      return response.data['isDuplicate'] ?? false;
    } catch (e) {
      print('Check duplicate ID error: $e');
      rethrow;
    }
  }

  Future<void> signup(String loginId, String password, String name) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/auth/signup',
        data: {'loginId': loginId, 'password': password, 'name': name},
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> requestPasswordReset(String loginId, String name) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/auth/password-reset/request',
        data: {'loginId': loginId, 'name': name},
      );
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('비밀번호 재설정 인증번호 발송 중 오류가 발생했습니다.');
    }
  }

  Future<void> confirmPasswordReset(
    String loginId,
    String code,
    String newPassword,
  ) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/auth/password-reset/confirm',
        data: {'loginId': loginId, 'code': code, 'newPassword': newPassword},
      );
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('비밀번호 재설정 중 오류가 발생했습니다.');
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      // 💡 [FCM 토큰 클리어 보장] 백엔드가 로그인 사용자를 식별해 FCM 토큰을 지울 수 있도록,
      // 로컬 토큰을 삭제하기 전에 먼저 백엔드 로그아웃 API를 호출합니다.
      await dio.post('/auth/logout');

      final storage = ref.read(secureStorageProvider);
      await storage.delete(key: 'jwt_token');

      state = const AsyncValue.data(null);
    } catch (e) {
      print('Logout API call failed: $e');
      final storage = ref.read(secureStorageProvider);
      await storage.delete(key: 'jwt_token');
      state = const AsyncValue.data(null);
    } finally {
      // 💡 [로그아웃 캐시 찌꺼기 제거] 로그아웃 후 다른 사용자로 재로그인 시
      // 이전 사용자의 캐시된 데이터가 노출되는 현상을 막기 위해 전역 상태들을 강제 무효화합니다.
      ref.invalidate(myPageProvider);
      ref.invalidate(noticesProvider);
      ref.invalidate(communityPostsProvider);
    }
  }
}
