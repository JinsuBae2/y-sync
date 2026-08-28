import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/my_comment.dart';
import '../providers/community_provider.dart';
import '../providers/notice_provider.dart';
import '../theme/app_design_tokens.dart';
import 'community_detail_screen.dart';
import 'notice_detail_screen.dart';

class MyCommentsScreen extends ConsumerWidget {
  const MyCommentsScreen({super.key, required this.comments});

  final List<MyComment> comments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          '내가 남긴 댓글',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDesignTokens.contentMaxWidth,
          ),
          child: comments.isEmpty
              ? const _EmptyComments()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                  itemCount: comments.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppDesignTokens.divider),
                  itemBuilder: (context, index) => _CommentRow(
                    comment: comments[index],
                    onTap: () => _openOrigin(context, ref, comments[index]),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _openOrigin(
    BuildContext context,
    WidgetRef ref,
    MyComment comment,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('원문을 불러오는 중입니다.'),
        duration: Duration(milliseconds: 600),
      ),
    );

    try {
      if (comment.category == 'NOTICE') {
        final notice = await ref
            .read(noticeNotifierProvider)
            .getNotice(comment.postId);
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice)),
        );
      } else {
        final post = await ref
            .read(communityNotifierProvider)
            .getPost(comment.postId);
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CommunityDetailScreen(post: post)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('원문을 불러올 수 없습니다.')));
    }
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.onTap});

  final MyComment comment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
                      color: comment.isDeleted
                          ? AppDesignTokens.coral.withValues(alpha: 0.08)
                          : AppDesignTokens.paleBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      comment.isDeleted
                          ? '삭제됨'
                          : _categoryLabel(comment.category),
                      style: TextStyle(
                        color: comment.isDeleted
                            ? AppDesignTokens.coral
                            : AppDesignTokens.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(comment.createdAt),
                    style: const TextStyle(
                      color: AppDesignTokens.subtle,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                comment.isDeleted
                    ? comment.isDeletedByAdmin
                          ? '관리자에 의해 삭제된 댓글입니다.'
                          : '작성자가 삭제한 댓글입니다.'
                    : comment.content,
                style: TextStyle(
                  color: comment.isDeleted
                      ? AppDesignTokens.coral
                      : AppDesignTokens.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              if (comment.isDeleted &&
                  comment.isDeletedByAdmin &&
                  comment.deletionReason != null) ...[
                const SizedBox(height: 5),
                Text(
                  '삭제 사유: ${comment.deletionReason}',
                  style: const TextStyle(
                    color: AppDesignTokens.coral,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 13),
              Row(
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 17,
                    color: AppDesignTokens.subtle,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      comment.postTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppDesignTokens.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: AppDesignTokens.subtle,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 42,
          color: AppDesignTokens.subtle,
        ),
        SizedBox(height: 16),
        Text(
          '남긴 댓글이 없습니다',
          style: TextStyle(
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
  'NOTICE' => '공지',
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
