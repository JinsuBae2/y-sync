import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/community_post.dart';
import 'notice_provider.dart';

// 💡 현재 선택된 커뮤니티 카테고리를 관리합니다. (Riverpod 3.x 호환 Notifier 사용)
class CommunityCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void updateCategory(String category) {
    state = category;
  }
}

final communityCategoryProvider = NotifierProvider<CommunityCategoryNotifier, String>(() {
  return CommunityCategoryNotifier();
});

// 💡 커뮤니티 게시글 목록을 가져오는 Provider입니다.
final communityPostsProvider = FutureProvider<List<CommunityPost>>((ref) async {
  final dio = ref.watch(dioProvider);
  final category = ref.watch(communityCategoryProvider);
  
  final response = await dio.get(
    '/community', 
    queryParameters: category == 'ALL' ? null : {'category': category}
  );
  
  final List<dynamic> data = response.data;
  return data
      .map((json) => CommunityPost.fromJson(json))
      .toList();
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
  }) async {
    final dio = ref.read(dioProvider);
    await dio.post('/community', data: {
      'category': category,
      'title': title,
      'content': content,
      'anonymous': anonymous,
    });
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
}

final communityNotifierProvider = Provider((ref) => CommunityNotifier(ref));
