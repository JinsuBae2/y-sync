import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import 'notice_provider.dart';
import 'community_provider.dart'; // 💡 [Bug4 Fix] 커뮤니티 목록 갱신을 위해 추가

// 💡 댓글이 속한 게시판의 종류를 정의합니다.
enum CommentSource { notice, community }

// 💡 게시판 종류와 ID를 기반으로 댓글 목록을 관리하는 Provider입니다.
final commentsProvider = FutureProvider.family<List<Comment>, ({CommentSource source, int id})>((ref, arg) async {
  final dio = ref.watch(dioProvider);
  
  // 소스에 따라 API 경로를 분기합니다.
  final path = arg.source == CommentSource.notice 
      ? '/notices/${arg.id}/comments' 
      : '/community/${arg.id}/comments';
      
  final response = await dio.get(path);
  
  final List<dynamic> data = response.data;
  return data.map((json) => Comment.fromJson(json)).toList();
});

class CommentNotifier {
  final Ref ref;

  CommentNotifier(this.ref);

  // 💡 댓글 작성 (소스와 ID, 대댓글 parentId에 따라 분기)
  Future<void> createComment(CommentSource source, int id, String content, {int? parentId}) async {
    final dio = ref.read(dioProvider);
    final path = source == CommentSource.notice 
        ? '/notices/$id/comments' 
        : '/community/$id/comments';

    await dio.post(path, data: {
      'content': content,
      'parentId': parentId, // 💡 대댓글을 위한 부모 ID 추가
    });
    
    // 해당 게시물의 댓글 목록 새로고침
    ref.invalidate(commentsProvider((source: source, id: id)));
    
    // 💡 [Bug4 Fix] 목록 화면의 commentCount 반영을 위해 게시글 목록도 새로고침
    if (source == CommentSource.notice) {
      ref.invalidate(noticesProvider);
    } else {
      ref.invalidate(communityPostsProvider);
    }
  }

  // 💡 댓글 삭제
  Future<void> deleteComment(CommentSource source, int id, int commentId) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/comments/$commentId');
    
    // 해당 게시물의 댓글 목록 새로고침
    ref.invalidate(commentsProvider((source: source, id: id)));
    
    // 💡 [Bug4 Fix] 목록 화면의 commentCount 반영을 위해 게시글 목록도 새로고침
    if (source == CommentSource.notice) {
      ref.invalidate(noticesProvider);
    } else {
      ref.invalidate(communityPostsProvider);
    }
  }

  // 💡 관리자용 댓글 삭제 (소프트 딜리트)
  Future<void> deleteCommentByAdmin(CommentSource source, int id, int commentId, String reason) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/admin/comments/$commentId', data: {'reason': reason});
    
    ref.invalidate(commentsProvider((source: source, id: id)));
    
    // 💡 [Bug4 Fix] 목록 화면의 commentCount 반영
    if (source == CommentSource.notice) {
      ref.invalidate(noticesProvider);
    } else {
      ref.invalidate(communityPostsProvider);
    }
  }
}

final commentNotifierProvider = Provider((ref) => CommentNotifier(ref));

// 💡 대댓글(답글) 작성 시 선택된 부모 댓글 상태를 포스트 ID별로 추적하는 Notifier입니다. (Riverpod 3.x 호환)
class ActiveParentCommentNotifier extends Notifier<Map<int, Comment?>> {
  @override
  Map<int, Comment?> build() => {};

  void updateState(int postId, Comment? comment) {
    state = {
      ...state,
      postId: comment,
    };
  }
}

final activeParentCommentProvider = NotifierProvider<ActiveParentCommentNotifier, Map<int, Comment?>>(
  ActiveParentCommentNotifier.new,
);
