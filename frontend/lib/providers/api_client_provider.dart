import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../screens/login_screen.dart';
import '../services/push_notification_service.dart';
import 'server_availability_provider.dart';
import 'session_provider.dart';

// Secure storage instance
final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 💡 매 요청마다 SecureStorage에서 JWT 토큰을 읽어와 Authorization 헤더에 추가합니다.
        final storage = ref.read(secureStorageProvider);
        final token = await storage.read(key: 'jwt_token');

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        ref.read(serverAvailabilityProvider.notifier).markAvailable();
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        if (isServerUnavailableError(e)) {
          ref.read(serverAvailabilityProvider.notifier).markUnavailable();
        }
        if (e.response?.statusCode == 401) {
          // 💡 401 Unauthorized 발생 시 좀비 토큰일 수 있으므로 로컬 세션(토큰) 삭제 및 강제 로그인 창 이동
          final storage = ref.read(secureStorageProvider);
          ref.read(sessionMemberIdProvider.notifier).clear();
          await storage.delete(key: 'jwt_token');

          // 순환 참조(Circular Dependency) 방지를 위해 authProvider 대신 전역 네비게이터를 사용합니다.
          PushNotificationService.navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
});
