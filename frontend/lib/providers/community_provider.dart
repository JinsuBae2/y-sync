import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../models/community_post.dart';
import '../utils/platform_file_multipart.dart';
import 'api_client_provider.dart';
import 'session_provider.dart';

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

typedef _CommunityFilters = ({
  String category,
  String grade,
  String keyword,
  int? memberId,
});

class CommunityPostsNotifier extends AsyncNotifier<List<CommunityPost>> {
  static const pageSize = 20;
  _CommunityFilters? _filters;
  String? _cursor;
  int _generation = 0;
  int _loadedCount = pageSize;
  bool isLoadingMore = false;
  bool loadMoreFailed = false;
  bool get hasNext => _cursor != null;

  @override
  Future<List<CommunityPost>> build() async {
    final filters = (
      category: ref.watch(communityCategoryProvider),
      grade: ref.watch(communityGradeProvider),
      keyword: ref.watch(communitySearchKeywordProvider).trim(),
      memberId: ref.watch(sessionMemberIdProvider),
    );
    if (_filters != filters) _loadedCount = pageSize;
    _filters = filters;
    final generation = ++_generation;
    isLoadingMore = false;
    loadMoreFailed = false;
    // 상세 복귀나 댓글 갱신에서도 이미 읽은 범위까지 받아 한 번에 교체합니다.
    final items = <CommunityPost>[];
    final ids = <int>{};
    String? cursor;
    do {
      final page = await _fetch(filters, cursor);
      items.addAll(page.items.where((post) => ids.add(post.id)));
      cursor = page.cursor;
    } while (items.length < _loadedCount &&
        cursor != null &&
        ref.mounted &&
        generation == _generation);
    if (ref.mounted && generation == _generation) {
      _cursor = cursor;
      _loadedCount = items.length;
    }
    return items;
  }

  Future<({List<CommunityPost> items, String? cursor})> _fetch(
    _CommunityFilters filters,
    String? cursor,
  ) async {
    final response = await ref
        .read(dioProvider)
        .get(
          '/community/feed',
          queryParameters: {
            'size': pageSize,
            'category': filters.category,
            'grade': filters.grade,
            if (filters.keyword.isNotEmpty) 'keyword': filters.keyword,
            'cursor': ?cursor,
          },
        );
    final data = response.data as Map<String, dynamic>;
    return (
      items: (data['items'] as List)
          .map((json) => CommunityPost.fromJson(json as Map<String, dynamic>))
          .toList(),
      cursor: data['hasNext'] == true ? data['nextCursor'] as String? : null,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        state.isLoading ||
        isLoadingMore ||
        !hasNext ||
        _filters == null) {
      return;
    }
    final generation = _generation;
    isLoadingMore = true;
    loadMoreFailed = false;
    state = AsyncData(List.of(current));
    try {
      final page = await _fetch(_filters!, _cursor);
      if (!ref.mounted || generation != _generation || state.isLoading) return;
      final ids = current.map((post) => post.id).toSet();
      final merged = [
        ...current,
        ...page.items.where((post) => ids.add(post.id)),
      ];
      _cursor = page.cursor;
      _loadedCount = merged.length;
      isLoadingMore = false;
      state = AsyncData(merged);
    } catch (_) {
      if (!ref.mounted || generation != _generation || state.isLoading) return;
      isLoadingMore = false;
      loadMoreFailed = true;
      state = AsyncData(List.of(current));
    }
  }

  Future<void> refresh() async {
    _loadedCount = pageSize;
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // 최초 페이지 오류는 화면의 재시도 안내로 표시합니다.
    }
  }
}

final communityPostsProvider =
    AsyncNotifierProvider<CommunityPostsNotifier, List<CommunityPost>>(
      CommunityPostsNotifier.new,
    );

// 관리자 목록은 커뮤니티의 검색·분류 상태를 공유하지 않습니다.
final adminCommunityPostsProvider =
    FutureProvider.autoDispose<List<CommunityPost>>((ref) async {
      ref.watch(sessionMemberIdProvider);
      final dio = ref.watch(dioProvider);
      final response = await dio.get('/community');
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
    ProgressCallback? onSendProgress,
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

    await dio.post(
      '/community',
      data: formData,
      onSendProgress: onSendProgress,
    );
    ref.invalidate(communityPostsProvider);
    ref.invalidate(adminCommunityPostsProvider);
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
    ProgressCallback? onSendProgress,
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

    await dio.put(
      '/community/$id',
      data: formData,
      onSendProgress: onSendProgress,
    );
    ref.invalidate(communityPostsProvider);
    ref.invalidate(adminCommunityPostsProvider);
  }

  // 💡 게시글 삭제
  Future<void> deletePost(int id) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/community/$id');
    ref.invalidate(communityPostsProvider);
    ref.invalidate(adminCommunityPostsProvider);
  }

  // 💡 관리자용 게시글 삭제 (소프트 딜리트)
  Future<void> deletePostByAdmin(int id, String reason) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/admin/posts/$id', data: {'reason': reason});
    ref.invalidate(communityPostsProvider);
    ref.invalidate(adminCommunityPostsProvider);
  }

  // 💡 관리자용 게시글 복구 (소프트 딜리트 해제)
  Future<void> restorePostByAdmin(int id) async {
    final dio = ref.read(dioProvider);
    await dio.post('/admin/posts/$id/restore');
    ref.invalidate(communityPostsProvider);
    ref.invalidate(adminCommunityPostsProvider);
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
    ref.invalidate(adminCommunityPostsProvider);
  }
}

final communityNotifierProvider = Provider((ref) => CommunityNotifier(ref));
