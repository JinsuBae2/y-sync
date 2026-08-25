import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_post.dart';
import '../providers/auth_provider.dart';
import '../providers/comment_provider.dart';
import '../providers/community_provider.dart';
import '../theme/app_design_tokens.dart';
import '../utils/image_url_helper.dart';
import '../widgets/comment_thread.dart';
import '../widgets/deletion_reason_dialog.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/linkify_text.dart';

class CommunityDetailScreen extends ConsumerWidget {
  const CommunityDetailScreen({super.key, required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authProvider).asData?.value;
    final isAdmin = member?.role == 'ADMIN' || member?.role == 'SUPER_ADMIN';
    final canDelete = member != null && (isAdmin || member.id == post.memberId);
    final canReport = member != null && !isAdmin && member.id != post.memberId;

    if (post.isDeleted && !isAdmin) {
      return _DeletedPostScreen(reason: post.deletionReason);
    }

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          '커뮤니티',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (canReport)
            IconButton(
              tooltip: '게시글 신고',
              onPressed: () => _showReportBottomSheet(
                context,
                ref,
                targetType: 'POST',
                targetId: post.id,
              ),
              icon: const Icon(
                Icons.flag_outlined,
                color: AppDesignTokens.coral,
              ),
            ),
          if (canDelete)
            IconButton(
              tooltip: '게시글 삭제',
              onPressed: () => _confirmDelete(context, ref, isAdmin: isAdmin),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDesignTokens.contentMaxWidth,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PostMeta(post: post),
                      const SizedBox(height: 16),
                      Text(
                        post.title,
                        style: const TextStyle(
                          color: AppDesignTokens.navy,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AuthorRow(post: post),
                      if (post.isDeleted) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.coral.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '삭제된 게시글${post.deletionReason == null ? '' : ' · ${post.deletionReason}'}',
                            style: const TextStyle(
                              color: AppDesignTokens.coral,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: AppDesignTokens.divider),
                      const SizedBox(height: 24),
                      LinkifyText(
                        text: post.content,
                        style: const TextStyle(
                          color: AppDesignTokens.navy,
                          fontSize: 15,
                          height: 1.7,
                        ),
                      ),
                      if (post.imageUrls case final images?
                          when images.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        for (final image in images)
                          _PostImage(
                            url: image,
                            images: images,
                            onOpen: (index) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageViewerScreen(
                                  imageUrls: images
                                      .map(getCleanImageUrl)
                                      .toList(),
                                  initialIndex: index,
                                ),
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          const Text(
                            '댓글',
                            style: TextStyle(
                              color: AppDesignTokens.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${post.commentCount}',
                            style: const TextStyle(
                              color: AppDesignTokens.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppDesignTokens.divider),
                      CommentListSection(
                        source: CommentSource.community,
                        postId: post.id,
                        onReport: (reportContext, commentId) =>
                            _showReportBottomSheet(
                              reportContext,
                              ref,
                              targetType: 'COMMENT',
                              targetId: commentId,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              CommentComposer(source: CommentSource.community, postId: post.id),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref, {
    required bool isAdmin,
  }) async {
    try {
      if (isAdmin) {
        final reason = await showDialog<String>(
          context: context,
          builder: (_) => const DeletionReasonDialog(),
        );
        if (reason == null) return;
        await ref
            .read(communityNotifierProvider)
            .deletePostByAdmin(post.id, reason);
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('게시글 삭제'),
            content: const Text('이 게시글을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  '삭제',
                  style: TextStyle(color: AppDesignTokens.coral),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await ref.read(communityNotifierProvider).deletePost(post.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('게시글이 삭제되었습니다.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $error')));
    }
  }

  Future<void> _showReportBottomSheet(
    BuildContext context,
    WidgetRef ref, {
    required String targetType,
    required int targetId,
  }) async {
    const reasons = [
      '스팸·홍보·도배',
      '음란하거나 선정적인 내용',
      '욕설·혐오·비하 표현',
      '개인정보 노출 또는 권리 침해',
      '기타 부적절한 내용',
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppDesignTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '신고 사유',
                style: TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '가장 가까운 사유를 선택해주세요.',
                style: TextStyle(color: AppDesignTokens.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < reasons.length; index++) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: AppDesignTokens.coral,
                    size: 20,
                  ),
                  title: Text(
                    reasons[index],
                    style: const TextStyle(
                      color: AppDesignTokens.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppDesignTokens.subtle,
                  ),
                  onTap: () => Navigator.pop(sheetContext, reasons[index]),
                ),
                if (index != reasons.length - 1)
                  const Divider(height: 1, color: AppDesignTokens.divider),
              ],
            ],
          ),
        ),
      ),
    );
    if (reason == null || !context.mounted) return;

    try {
      await ref
          .read(communityNotifierProvider)
          .reportTarget(
            targetType: targetType,
            targetId: targetId,
            reason: reason,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
    } catch (error) {
      if (!context.mounted) return;
      var message = error.toString();
      if (error is DioException && error.response?.data != null) {
        message = error.response!.data.toString();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('신고 실패: $message')));
    }
  }
}

class _DeletedPostScreen extends StatelessWidget {
  const _DeletedPostScreen({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '커뮤니티',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block_outlined,
                size: 42,
                color: AppDesignTokens.subtle,
              ),
              const SizedBox(height: 14),
              const Text(
                '삭제된 게시글입니다.',
                style: TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (reason != null) ...[
                const SizedBox(height: 7),
                Text(
                  '사유: $reason',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppDesignTokens.muted,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('목록으로'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesignTokens.navy,
                  side: const BorderSide(color: AppDesignTokens.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostMeta extends StatelessWidget {
  const _PostMeta({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppDesignTokens.paleBlue,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _categoryLabel(post.category),
            style: const TextStyle(
              color: AppDesignTokens.blue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _gradeLabel(post.targetGrade),
          style: const TextStyle(
            color: AppDesignTokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          _formatDate(post.createdAt),
          style: const TextStyle(color: AppDesignTokens.subtle, fontSize: 12),
        ),
      ],
    );
  }

  static String _categoryLabel(String value) {
    return switch (value) {
      'QA' => 'Q&A',
      'TEAM' => '팀원 모집',
      _ => '자유',
    };
  }

  static String _gradeLabel(String value) {
    return switch (value) {
      'GRADE_1' => '1학년',
      'GRADE_2' => '2학년',
      'GRADE_3' => '3학년',
      _ => '전체 학년',
    };
  }

  static String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.split('T').first;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: post.anonymous
                ? AppDesignTokens.background
                : AppDesignTokens.paleBlue,
            borderRadius: BorderRadius.circular(7),
            border: post.anonymous
                ? Border.all(color: AppDesignTokens.divider)
                : null,
          ),
          child: Icon(
            post.anonymous
                ? Icons.person_off_outlined
                : Icons.person_outline_rounded,
            size: 19,
            color: post.anonymous
                ? AppDesignTokens.muted
                : AppDesignTokens.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            post.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppDesignTokens.navy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(
          Icons.visibility_outlined,
          size: 16,
          color: AppDesignTokens.subtle,
        ),
        const SizedBox(width: 4),
        Text(
          '${post.viewCount}',
          style: const TextStyle(color: AppDesignTokens.subtle, fontSize: 12),
        ),
      ],
    );
  }
}

class _PostImage extends StatelessWidget {
  const _PostImage({
    required this.url,
    required this.images,
    required this.onOpen,
  });

  final String url;
  final List<String> images;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(images.indexOf(url)),
          child: Image.network(
            getCleanImageUrl(url),
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppDesignTokens.blue,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => const SizedBox(
              height: 140,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: AppDesignTokens.subtle,
                    ),
                    SizedBox(height: 7),
                    Text(
                      '이미지를 불러올 수 없습니다.',
                      style: TextStyle(
                        color: AppDesignTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
