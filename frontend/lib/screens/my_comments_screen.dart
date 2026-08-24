import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/my_comment.dart';
import '../providers/community_provider.dart';
import '../providers/notice_provider.dart';
import 'community_detail_screen.dart';
import 'notice_detail_screen.dart';

/// 💡 내가 남긴 댓글들을 확인하고 즉시 원본 글로 이동할 수 있는 독립 화면입니다.
class MyCommentsScreen extends ConsumerWidget {
  final List<MyComment> comments;

  const MyCommentsScreen({
    super.key,
    required this.comments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '내가 남긴 댓글',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: comments.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _navigateToOriginPost(context, ref, comment),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.comment_outlined, size: 16, color: Color(0xFF164687)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '내가 작성한 댓글',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _formatDate(comment.createdAt.toString()),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              comment.isDeleted 
                                  ? '🛡️ 관리자에 의해 삭제된 댓글입니다.' 
                                  : comment.content,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: comment.isDeleted ? Colors.red.shade400 : Colors.black87,
                                fontStyle: comment.isDeleted ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                            if (comment.isDeleted && comment.deletionReason != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '사유: ${comment.deletionReason}',
                                style: TextStyle(fontSize: 13, color: Colors.red.shade300, fontStyle: FontStyle.italic),
                              ),
                            ],
                            const SizedBox(height: 14),
                            // 💡 원본 게시글 링크 배너
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.link_rounded, size: 16, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '원문: ${comment.postTitle}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.blueGrey),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // 💡 댓글 작성 원문글로 텔레포트 및 상세 화면 연동
  Future<void> _navigateToOriginPost(BuildContext context, WidgetRef ref, MyComment comment) async {
    try {
      // 💡 로딩 상태를 직관적으로 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('게시글 정보를 가져오고 있습니다...'),
            ],
          ),
          duration: Duration(milliseconds: 800),
        ),
      );

      // 💡 댓글이 Notice에 달린 경우인지, Community에 달린 경우인지 구분하여 로드
      // DTO 속성에 따라 postTitle이나 notice 여부 판단 필요
      // 보통 notices에 단 댓글인지 판별하기 위해 noticeId 속성 등이 존재할 수 있음
      // MyComment 모델 속성을 보거나 임시 예외 처리
      // MyComment 객체에 noticeId가 있는지 검사하기 위해 providers나 getPost 호출
      // getPost API를 통해 커뮤니티 글을 우선 가져오고, 없으면 공지사항으로 처리
      final post = await ref.read(communityNotifierProvider).getPost(comment.postId);
      
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommunityDetailScreen(post: post),
          ),
        );
      }
    } catch (e) {
      // 💡 커뮤니티 글 페치 실패 시 공지사항으로 폴백 시도
      try {
        final notice = await ref.read(noticeNotifierProvider).getNotice(comment.postId);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(notice: notice),
            ),
          );
        }
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('게시글을 불러올 수 없습니다: $e')),
          );
        }
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.comment_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            '내가 남긴 댓글이 없습니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
