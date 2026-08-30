import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../models/community_post.dart';
import '../utils/platform_file_multipart.dart';
import 'notice_provider.dart';

// 💡 현재 선택된 커뮤니티 카테고리를 관리합니다. (Riverpod 3.x 호환 Notifier 사용)
class CommunityCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void updateCategory(String category) {
    state = category;
  }
}

final communityCategoryProvider =
    NotifierProvider<CommunityCategoryNotifier, String>(() {
      return CommunityCategoryNotifier();
    });

// 💡 현재 검색어를 관리하는 Provider입니다.
class CommunitySearchKeywordNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateKeyword(String keyword) {
    state = keyword;
  }
}

final communitySearchKeywordProvider =
    NotifierProvider<CommunitySearchKeywordNotifier, String>(() {
      return CommunitySearchKeywordNotifier();
    });

// 💡 현재 선택된 학년 탭을 관리합니다.
class CommunityGradeNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void updateGrade(String grade) {
    state = grade;
  }
}

final communityGradeProvider = NotifierProvider<CommunityGradeNotifier, String>(
  () {
    return CommunityGradeNotifier();
  },
);

final communityPostsProvider = FutureProvider<List<CommunityPost>>((ref) async {
  final dio = ref.watch(dioProvider);
  final category = ref.watch(communityCategoryProvider);
  final keyword = ref.watch(communitySearchKeywordProvider);

  String path = '/community';
  Map<String, dynamic> queryParams = {};

  if (category != 'ALL') {
    queryParams['category'] = category;
  }
  if (keyword.trim().isNotEmpty) {
    path = '/community/search';
    queryParams['keyword'] = keyword.trim();
  }

  final response = await dio.get(
    path,
    queryParameters: queryParams.isEmpty ? null : queryParams,
  );

  final List<dynamic> data = response.data;
  return data.map((json) => CommunityPost.fromJson(json)).toList();
});

class CommunityNotifier {
  final Ref ref;

  CommunityNotifier(this.ref);

  // 💡 단건 게시글 조회
  Future<CommunityPost> getPost(int id) async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/community/$id');
    return CommunityPost.fromJson(response.data);
  }

  // 💡 게시글 작성
  Future<void> createPost({
    required String category,
    required String title,
    required String content,
    required bool anonymous,
    required String targetGrade,
    List<PlatformFile>? files,
  }) async {
    final dio = ref.read(dioProvider);

    final formData = FormData();

    // JSON 데이터 파트 추가
    formData.files.add(
      MapEntry(
        'request',
        MultipartFile.fromString(
          jsonEncode({
            'category': category,
            'title': title,
            'content': content,
            'anonymous': anonymous,
            'targetGrade': targetGrade,
            'isPinned': false,
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

    await dio.post('/community', data: formData);
    ref.invalidate(communityPostsProvider);
  }

  // 작성자 본인의 게시글을 수정하며 새 파일이 선택된 경우에만 기존 첨부를 교체합니다.
  Future<void> updatePost({
    required int id,
    required String category,
    required String title,
    required String content,
    required bool anonymous,
    required String targetGrade,
    List<PlatformFile>? files,
  }) async {
    final dio = ref.read(dioProvider);
    final formData = FormData();

    formData.files.add(
      MapEntry(
        'request',
        MultipartFile.fromString(
          jsonEncode({
            'category': category,
            'title': title,
            'content': content,
            'anonymous': anonymous,
            'targetGrade': targetGrade,
            'isPinned': false,
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

    await dio.put('/community/$id', data: formData);
    ref.invalidate(communityPostsProvider);
  }

  // 💡 게시글 삭제
  Future<void> deletePost(int id) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/community/$id');
    ref.invalidate(communityPostsProvider);
  }

  // 💡 관리자용 게시글 삭제 (소프트 딜리트)
  Future<void> deletePostByAdmin(int id, String reason) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/admin/posts/$id', data: {'reason': reason});
    ref.invalidate(communityPostsProvider);
  }

  // 💡 관리자용 게시글 복구 (소프트 딜리트 해제)
  Future<void> restorePostByAdmin(int id) async {
    final dio = ref.read(dioProvider);
    await dio.post('/admin/posts/$id/restore');
    ref.invalidate(communityPostsProvider);
  }

  // 💡 게시글 또는 댓글 신고
  Future<void> reportTarget({
    required String targetType,
    required int targetId,
    required String reason,
  }) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '/reports',
      data: {'targetType': targetType, 'targetId': targetId, 'reason': reason},
    );
    ref.invalidate(communityPostsProvider);
  }
}

final communityNotifierProvider = Provider((ref) => CommunityNotifier(ref));
