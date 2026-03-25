import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/notice.dart';

// Global variable to store session ID in memory
String? _sessionId;

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    // Android Emulator: 10.0.2.2, iOS/Web: localhost
    baseUrl: 'http://10.0.2.2:8080/api/v1',
    // Enable sending cookies (JSESSIONID) for cross-origin requests on Web
    extra: {'withCredentials': true},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (_sessionId != null) {
        options.headers['Cookie'] = 'JSESSIONID=$_sessionId';
      }
      return handler.next(options);
    },
    onResponse: (response, handler) {
      final cookies = response.headers['set-cookie'];
      if (cookies != null) {
        for (var cookie in cookies) {
          if (cookie.contains('JSESSIONID=')) {
            final parts = cookie.split(';');
            for (var part in parts) {
              if (part.trim().startsWith('JSESSIONID=')) {
                _sessionId = part.trim().substring('JSESSIONID='.length);
                break;
              }
            }
          }
        }
      }
      return handler.next(response);
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
  
  final List<dynamic> data = response.data;
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

  Future<void> createNotice(String title, String content, String noticeType) async {
    final dio = ref.read(dioProvider);
    await dio.post('/admin/notices', data: {
      'title': title,
      'content': content,
      'noticeType': noticeType,
    });
    ref.invalidate(noticesProvider);
  }

  Future<void> updateNotice(int id, String title, String content, String noticeType) async {
    final dio = ref.read(dioProvider);
    await dio.put('/admin/notices/$id', data: {
      'title': title,
      'content': content,
      'noticeType': noticeType,
    });
    ref.invalidate(noticesProvider);
  }

  Future<void> deleteNotice(int id) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/admin/notices/$id');
    ref.invalidate(noticesProvider);
  }
}

final noticeNotifierProvider = Provider((ref) => NoticeNotifier(ref));
