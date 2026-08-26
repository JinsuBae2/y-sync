import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/notice.dart';
import '../theme/app_design_tokens.dart';
import 'deep_link_loading_screen.dart';

class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({
    super.key,
    required this.posts,
    this.notices,
    this.isNoticeOnly = false,
  });

  final List<CommunityPost> posts;
  final List<Notice>? notices;
  final bool isNoticeOnly;

  @override
  Widget build(BuildContext context) {
    final title = isNoticeOnly ? '작성한 공지사항' : '내가 쓴 게시글';
    final itemCount = isNoticeOnly ? notices?.length ?? 0 : posts.length;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDesignTokens.contentMaxWidth,
          ),
          child: itemCount == 0
              ? _EmptyPosts(isNoticeOnly: isNoticeOnly)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                  itemCount: itemCount,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppDesignTokens.divider),
                  itemBuilder: (context, index) => isNoticeOnly
                      ? _NoticeRow(
                          notice: notices![index],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeepLinkLoadingScreen(
                                targetType: 'NOTICE',
                                targetId: '${notices![index].id}',
                              ),
                            ),
                          ),
                        )
                      : _PostRow(
                          post: posts[index],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeepLinkLoadingScreen(
                                targetType: 'COMMUNITY',
                                targetId: '${posts[index].id}',
                              ),
                            ),
                          ),
                        ),
                ),
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post, required this.onTap});

  final CommunityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ActivityRow(
    label: _categoryLabel(post.category),
    date: _formatDate(post.createdAt),
    title: post.isDeleted ? '관리자에 의해 삭제된 게시글입니다.' : post.title,
    body: post.isDeleted
        ? post.deletionReason == null
              ? null
              : '삭제 사유: ${post.deletionReason}'
        : post.content,
    isDeleted: post.isDeleted,
    metrics: '댓글 ${post.commentCount}  ·  조회 ${post.viewCount}',
    onTap: onTap,
  );
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice, required this.onTap});

  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ActivityRow(
    label: notice.noticeType == 'NOTICE' ? '중요 공지' : '일반 공지',
    date: _formatDate(notice.createdAt),
    title: notice.title,
    body: notice.content,
    metrics: '댓글 ${notice.commentCount}  ·  조회 ${notice.viewCount}',
    onTap: onTap,
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.label,
    required this.date,
    required this.title,
    required this.body,
    required this.metrics,
    required this.onTap,
    this.isDeleted = false,
  });

  final String label;
  final String date;
  final String title;
  final String? body;
  final String metrics;
  final VoidCallback onTap;
  final bool isDeleted;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDeleted
                        ? AppDesignTokens.coral.withValues(alpha: 0.08)
                        : AppDesignTokens.paleBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isDeleted ? '삭제됨' : label,
                    style: TextStyle(
                      color: isDeleted
                          ? AppDesignTokens.coral
                          : AppDesignTokens.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  date,
                  style: const TextStyle(
                    color: AppDesignTokens.subtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDeleted ? AppDesignTokens.coral : AppDesignTokens.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 7),
              Text(
                body!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppDesignTokens.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              metrics,
              style: const TextStyle(
                color: AppDesignTokens.subtle,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyPosts extends StatelessWidget {
  const _EmptyPosts({required this.isNoticeOnly});

  final bool isNoticeOnly;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isNoticeOnly ? Icons.campaign_outlined : Icons.article_outlined,
          size: 42,
          color: AppDesignTokens.subtle,
        ),
        const SizedBox(height: 16),
        Text(
          isNoticeOnly ? '작성한 공지사항이 없습니다' : '작성한 게시글이 없습니다',
          style: const TextStyle(
            color: AppDesignTokens.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

String _categoryLabel(String category) => switch (category) {
  'QA' => 'Q&A',
  'TEAM' => '팀원 모집',
  _ => '자유',
};

String _formatDate(String value) {
  try {
    final date = DateTime.parse(value);
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return value;
  }
}
