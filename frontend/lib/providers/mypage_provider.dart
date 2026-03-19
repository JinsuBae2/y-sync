import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_post.dart';
import '../models/my_comment.dart';
import '../models/member.dart';
import '../models/notice.dart'; // 💡 추가
import 'notice_provider.dart';

// 💡 마이페이지의 전반적인 상태(프로필, 내 글, 내 댓글, 내 공지사항)를 통합 관리하는 Notifier입니다.
class MyPageNotifier extends AsyncNotifier<({Member member, List<CommunityPost> posts, List<MyComment> comments, List<Notice>? notices})> {
  @override
  Future<({Member member, List<CommunityPost> posts, List<MyComment> comments, List<Notice>? notices})> build() async {
    final dio = ref.watch(dioProvider);
    
    // 💡 기본 활동 내역 요청
    final futures = [
      dio.get('/members/me'),
      dio.get('/members/me/posts'),
      dio.get('/members/me/comments'),
    ];

    final responses = await Future.wait(futures);

    final memberJson = responses[0].data as Map<String, dynamic>;
    final member = Member.fromJson(memberJson);
    final postsJson = responses[1].data as List<dynamic>;
    final commentsJson = responses[2].data as List<dynamic>;

    List<Notice>? notices;
    // 💡 관리자(ADMIN)일 경우에만 내가 쓴 공지사항을 추가로 불러옵니다.
    if (member.role == 'ADMIN') {
      final noticeResponse = await dio.get('/members/me/notices');
      final noticesJson = noticeResponse.data as List<dynamic>;
      notices = noticesJson.map((json) => Notice.fromJson(json)).toList();
    }

    return (
      member: member,
      posts: postsJson.map((json) => CommunityPost.fromJson(json)).toList(),
      comments: commentsJson.map((json) => MyComment.fromJson(json)).toList(),
      notices: notices,
    );
  }

  // 💡 데이터 새로고침
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final myPageProvider = AsyncNotifierProvider<MyPageNotifier, ({Member member, List<CommunityPost> posts, List<MyComment> comments, List<Notice>? notices})>(() {
  return MyPageNotifier();
});
