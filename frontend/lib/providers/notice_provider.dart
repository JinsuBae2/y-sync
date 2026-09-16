import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../models/notice.dart';
import '../utils/platform_file_multipart.dart';
import 'api_client_provider.dart';

// 💡 현재 검색어를 관리하는 Provider입니다. (Riverpod 3.x 호환 Notifier 사용)
class SearchKeywordNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateKeyword(String keyword) {
    state = keyword;
  }
}

final searchKeywordProvider = NotifierProvider<SearchKeywordNotifier, String>(
  () {
    return SearchKeywordNotifier();
  },
);

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

  Future<void> createNotice(
    String title,
    String content,
    String noticeType, {
    String targetGrade = 'ALL',
    List<PlatformFile>? files,
    String? eventStartDate,
    String? eventEndDate,
  }) async {
    final dio = ref.read(dioProvider);
    final formData = FormData();

    formData.files.add(
      MapEntry(
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
      ),
    );

    if (files != null && files.isNotEmpty) {
      for (final file in files) {
        formData.files.add(
          MapEntry('files', await platformFileToMultipart(file)),
        );
      }
    }

    await dio.post('/notices', data: formData);
    ref.invalidate(noticesProvider);
  }

  Future<void> updateNotice(
    int id,
    String title,
    String content,
    String noticeType, {
    String targetGrade = 'ALL',
    List<PlatformFile>? files,
    String? eventStartDate,
    String? eventEndDate,
  }) async {
    final dio = ref.read(dioProvider);
    final formData = FormData();

    formData.files.add(
      MapEntry(
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
      ),
    );

    if (files != null && files.isNotEmpty) {
      for (final file in files) {
        formData.files.add(
          MapEntry('files', await platformFileToMultipart(file)),
        );
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
