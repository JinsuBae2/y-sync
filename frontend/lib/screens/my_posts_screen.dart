import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../models/notice.dart';
import 'community_detail_screen.dart';
import 'notice_detail_screen.dart';

/// 💡 내가 작성한 게시글 및 공지사항을 모아보는 세련된 독립 화면입니다.
class MyPostsScreen extends StatelessWidget {
  final List<CommunityPost> posts;
  final List<Notice>? notices;
  final bool isNoticeOnly;

  const MyPostsScreen({
    super.key,
    required this.posts,
    this.notices,
    this.isNoticeOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleText = isNoticeOnly ? '내가 작성한 공지사항' : '내가 쓴 게시글';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
      body: isNoticeOnly ? _buildNoticeList(context) : _buildPostList(context, theme),
    );
  }

  // 💡 내가 쓴 게시글 목록 빌드
  Widget _buildPostList(BuildContext context, ThemeData theme) {
    if (posts.isEmpty) {
      return _buildEmptyState(Icons.article_outlined, '작성한 게시글이 없습니다.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunityDetailScreen(post: post),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 💡 카테고리 배지
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            post.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(post.createdAt.toString()),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.isDeleted 
                          ? '🛡️ 관리자에 의해 삭제된 게시글입니다.' 
                          : post.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: post.isDeleted ? Colors.red.shade400 : Colors.black87,
                        fontStyle: post.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!post.isDeleted)
                      Text(
                        post.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                      ),
                    if (post.isDeleted && post.deletionReason != null)
                      Text(
                        '사유: ${post.deletionReason}',
                        style: TextStyle(fontSize: 13, color: Colors.red.shade300, fontStyle: FontStyle.italic),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.comment_outlined, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${post.commentCount}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${post.viewCount}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 💡 내가 쓴 공지사항 목록 빌드 (관리자용)
  Widget _buildNoticeList(BuildContext context) {
    if (notices == null || notices!.isEmpty) {
      return _buildEmptyState(Icons.campaign_rounded, '작성한 공지사항이 없습니다.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: notices!.length,
      itemBuilder: (context, index) {
        final notice = notices![index];
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoticeDetailScreen(notice: notice),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            notice.noticeType == 'EVENT' ? '행사/일정' : '일반공지',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(notice.createdAt.toString()),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      notice.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notice.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.comment_outlined, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${notice.commentCount}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 💡 빈 상태 레이아웃 빌드
  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // 💡 날짜 표시용 유틸 포맷팅 함수
  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
