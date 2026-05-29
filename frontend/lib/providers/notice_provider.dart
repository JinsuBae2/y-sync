import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../models/notice.dart';
import '../services/push_notification_service.dart';
import '../screens/login_screen.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Secure storage instance
final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080/api/v1',
);

const String imageBaseUrl = String.fromEnvironment(
  'IMAGE_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
  ));

  dio.interceptors.add(InterceptorsWrapper(
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
      return handler.next(response);
    },
    onError: (DioException e, handler) async {
      if (e.response?.statusCode == 401) {
        // 💡 401 Unauthorized 발생 시 좀비 토큰일 수 있으므로 로컬 세션(토큰) 삭제 및 강제 로그인 창 이동
        final storage = ref.read(secureStorageProvider);
        await storage.delete(key: 'jwt_token');
        
        // 순환 참조(Circular Dependency) 방지를 위해 authProvider 대신 전역 네비게이터를 사용합니다.
        PushNotificationService.navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      return handler.next(e);
    },
  ));

  return dio;
});

// 💡 현재 검색어를 관리하는 Provider입니다. (Riverpod 3.x 호환 Notifier 사용)
class SearchKeywordNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateKeyword(String keyword) {
    state = keyword;
  }
}

final searchKeywordProvider = NotifierProvider<SearchKeywordNotifier, String>(() {
  return SearchKeywordNotifier();
});

// 💡 현재 선택된 공지사항 학년 탭을 관리합니다.
class NoticeGradeNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void updateGrade(String grade) {
    state = grade;
  }
}

final noticeGradeProvider = NotifierProvider<NoticeGradeNotifier, String>(() {
  return NoticeGradeNotifier();
});

// 💡 공지사항 목록 데이터를 가져오는 Provider입니다.
// 검색어가 있을 경우 검색 API를, 없을 경우 전체 목록 API를 호출합니다.
final noticesProvider = FutureProvider<List<Notice>>((ref) async {
  final dio = ref.watch(dioProvider);
  final keyword = ref.watch(searchKeywordProvider);
  
  // 키워드가 비어있으면 전체 조회, 값이 있으면 검색 쿼리 사용
  final String path = keyword.trim().isEmpty 
      ? '/notices' 
      : '/notices/search?keyword=${Uri.encodeComponent(keyword.trim())}';
      
  final response = await dio.get(path);
  
  // 💡 백엔드 페이징 API 적용으로 인해, 전체 조회의 경우 Page<NoticeResponse> 형식(Map)으로 반환됩니다.
  final List<dynamic> data;
  if (keyword.trim().isEmpty) {
    data = response.data['content'] as List<dynamic>;
  } else {
    data = response.data as List<dynamic>;
  }
  
  return data.map((json) => Notice.fromJson(json)).toList();
});

class NoticeNotifier {
  final Ref ref;

  NoticeNotifier(this.ref);

  Future<Notice> getNotice(int id) async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/notices/$id');
    return Notice.fromJson(response.data);
  }

  Future<void> createNotice(String title, String content, String noticeType, {String targetGrade = 'ALL', List<String>? imagePaths, String? eventStartDate, String? eventEndDate}) async {
    final dio = ref.read(dioProvider);
    final formData = FormData();
    
    formData.files.add(MapEntry(
      'request',
      MultipartFile.fromString(
        jsonEncode({
          'title': title,
          'content': content,
          'noticeType': noticeType,
          'targetGrade': targetGrade,
          'isPinned': false,
          'eventStartDate': eventStartDate,
          'eventEndDate': eventEndDate,
        }),
        contentType: MediaType('application', 'json'),
      ),
    ));

    if (imagePaths != null && imagePaths.isNotEmpty) {
      for (String path in imagePaths) {
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(path),
        ));
      }
    }

    await dio.post('/notices', data: formData);
    ref.invalidate(noticesProvider);
  }

  Future<void> updateNotice(int id, String title, String content, String noticeType, {String targetGrade = 'ALL', List<String>? imagePaths, String? eventStartDate, String? eventEndDate}) async {
    final dio = ref.read(dioProvider);
    final formData = FormData();
    
    formData.files.add(MapEntry(
      'request',
      MultipartFile.fromString(
        jsonEncode({
          'title': title,
          'content': content,
          'noticeType': noticeType,
          'targetGrade': targetGrade,
          'isPinned': false,
          'eventStartDate': eventStartDate,
          'eventEndDate': eventEndDate,
        }),
        contentType: MediaType('application', 'json'),
      ),
    ));

    if (imagePaths != null && imagePaths.isNotEmpty) {
      for (String path in imagePaths) {
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(path),
        ));
      }
    }

    await dio.put('/notices/$id', data: formData);
    ref.invalidate(noticesProvider);
  }

  Future<void> deleteNotice(int id) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/notices/$id');
    ref.invalidate(noticesProvider);
  }
}

final noticeNotifierProvider = Provider((ref) => NoticeNotifier(ref));
