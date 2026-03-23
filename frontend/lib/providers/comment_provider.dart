import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import 'notice_provider.dart';

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

  // 💡 댓글 작성 (소스와 ID에 따라 분기)
  Future<void> createComment(CommentSource source, int id, String content) async {
    final dio = ref.read(dioProvider);
    final path = source == CommentSource.notice 
        ? '/notices/$id/comments' 
        : '/community/$id/comments';

    await dio.post(path, data: {
      'content': content,
    });
    
    // 해당 게시물의 댓글 목록 새로고침
    ref.invalidate(commentsProvider((source: source, id: id)));
  }

  // 💡 댓글 삭제
  Future<void> deleteComment(CommentSource source, int id, int commentId) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/comments/$commentId');
    
    // 해당 게시물의 댓글 목록 새로고침
    ref.invalidate(commentsProvider((source: source, id: id)));
  }

  // 💡 관리자용 댓글 삭제 (소프트 딜리트)
  Future<void> deleteCommentByAdmin(CommentSource source, int id, int commentId, String reason) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/admin/comments/$commentId', data: {'reason': reason});
    
    ref.invalidate(commentsProvider((source: source, id: id)));
  }
}

final commentNotifierProvider = Provider((ref) => CommentNotifier(ref));
