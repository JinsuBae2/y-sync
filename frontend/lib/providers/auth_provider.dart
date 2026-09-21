import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/member.dart';
import '../models/notice_grade_preference.dart';
import 'api_client_provider.dart';
import 'session_provider.dart';
import 'package:flutter/foundation.dart';

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
        debugPrint('FCM Token sent successfully');
      }
    } catch (e) {
      debugPrint('Failed to send FCM token to backend: $e');
    }
  }

  Future<Member?> _checkLoginStatus() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final token = await storage.read(key: 'jwt_token');

      if (token == null) {
        ref.read(sessionMemberIdProvider.notifier).clear();
        return null;
      }

      final dio = ref.read(dioProvider);
      final response = await dio.get('/members/me');

      // 💡 로그인 상태가 확인되면 FCM 토큰을 서버로 전송
      await _sendFcmToken(dio);

      final member = Member.fromJson(response.data);
      ref.read(sessionMemberIdProvider.notifier).activate(member.id);
      return member;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        // 토큰 만료 등
        final storage = ref.read(secureStorageProvider);
        ref.read(sessionMemberIdProvider.notifier).clear();
        await storage.delete(key: 'jwt_token');
        return null;
      }
      rethrow;
    }
  }

  Future<void> login(String loginId, String password) async {
    ref.read(sessionMemberIdProvider.notifier).clear();
    state = const AsyncValue.loading();
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
      state = const AsyncValue.data(null);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> socialLogin(
    String accessToken,
    String provider,
  ) async {
    ref.read(sessionMemberIdProvider.notifier).clear();
    state = const AsyncValue.loading();
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
        state = const AsyncValue.data(null);
        // 미가입자 -> 추가 정보 필요
        return response.data; // socialId, provider 포함
      }
      state = const AsyncValue.data(null);
      return null;
    } catch (e) {
      state = const AsyncValue.data(null);
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
    ref.read(sessionMemberIdProvider.notifier).clear();
    state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/social-signup',
        data: {
          'loginId': loginId,
          'name': name,
          'socialId': socialId,
          'provider': provider,
          'password': ?password,
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
      state = const AsyncValue.data(null);
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

  /// 💡 인증번호를 확인하고 가입 증표를 돌려받습니다.
  ///
  /// 증표는 인증을 통과한 이 응답에만 실려 옵니다. 가입 요청에 이 값을 제시해야 하며,
  /// 저장소에 남기지 않고 가입 화면이 메모리로만 들고 있다가 버립니다.
  Future<String?> verifyCode(String loginId, String code) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/verify-student/verify-code',
        data: {'loginId': loginId, 'code': code},
      );
      if (response.data['success'] != true) return null;
      return response.data['verificationGrant'] as String?;
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      rethrow;
    }
  }


  Future<void> signup(
    String loginId,
    String password,
    String name, {
    required String verificationGrant,
    NoticeGradePreference? noticeGradePreference,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/auth/signup',
        data: {
          'loginId': loginId,
          'password': password,
          'name': name,
          // 💡 인증을 통과한 주체임을 증명하는 값입니다. 없으면 서버가 가입을 거부합니다.
          'verificationGrant': verificationGrant,
          // 💡 확인 학년도는 보내지 않습니다. 단말기 시각과 무관하게 서버가 계산합니다.
          if (noticeGradePreference != null)
            'noticeGradePreference': noticeGradePreference.wireValue,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 💡 공지 알림 수신 학년을 저장하고 최신 회원 정보로 갱신합니다.
  ///
  /// 인증된 본인의 설정만 수정합니다. 요청에 대상 회원을 지정하는 값이 없으므로
  /// 학번이나 타인의 회원 ID로 다른 사람의 설정을 바꿀 수 없습니다.
  /// 저장이 실패하면 기존 선택과 확인 학년도가 그대로 유지되도록 상태를 건드리지 않습니다.
  Future<void> updateNoticeGradePreference(
    NoticeGradePreference preference,
  ) async {
    final dio = ref.read(dioProvider);
    final response = await dio.put(
      '/members/me/notice-grade',
      data: {'noticeGradePreference': preference.wireValue},
    );
    state = AsyncData(Member.fromJson(response.data));
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
    ref.read(sessionMemberIdProvider.notifier).clear();
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
      debugPrint('Logout API call failed: $e');
      final storage = ref.read(secureStorageProvider);
      await storage.delete(key: 'jwt_token');
      state = const AsyncValue.data(null);
    }
  }
}
