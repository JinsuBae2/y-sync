import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import 'notice_provider.dart';

final commentsProvider = FutureProvider.family<List<Comment>, int>((ref, noticeId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/notices/$noticeId/comments');
  
  final List<dynamic> data = response.data;
  return data.map((json) => Comment.fromJson(json)).toList();
});

class CommentNotifier {
  final Ref ref;

  CommentNotifier(this.ref);

  Future<void> createComment(int noticeId, String content) async {
    final dio = ref.read(dioProvider);
    await dio.post('/notices/$noticeId/comments', data: {
      'content': content,
    });
    // 해당 공지사항의 댓글 목록만 새로고침
    ref.invalidate(commentsProvider(noticeId));
  }

  Future<void> deleteComment(int noticeId, int commentId) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/comments/$commentId');
    // 해당 공지사항의 댓글 목록만 새로고침
    ref.invalidate(commentsProvider(noticeId));
  }
}

final commentNotifierProvider = Provider((ref) => CommentNotifier(ref));
