import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notice.dart';
import '../providers/auth_provider.dart';
import '../providers/comment_provider.dart';
import '../providers/notice_provider.dart';
import '../theme/app_design_tokens.dart';
import '../utils/image_url_helper.dart';
import '../widgets/comment_thread.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/linkify_text.dart';
import 'notice_form_screen.dart';

class NoticeDetailScreen extends ConsumerWidget {
  const NoticeDetailScreen({super.key, required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authProvider).asData?.value;
    final canEdit =
        member != null &&
        (member.role == 'ADMIN' ||
            member.role == 'SUPER_ADMIN' ||
            member.name == notice.authorName ||
            member.loginId == notice.authorName);

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          '공지사항',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: canEdit
            ? [
                IconButton(
                  tooltip: '공지 수정',
                  onPressed: () => _editNotice(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '공지 삭제',
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppDesignTokens.coral,
                  ),
                ),
                const SizedBox(width: 4),
              ]
            : null,
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
                      _NoticeMeta(notice: notice),
                      const SizedBox(height: 16),
                      Text(
                        notice.title,
                        style: const TextStyle(
                          color: AppDesignTokens.navy,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AuthorRow(notice: notice),
                      if (notice.eventStartDate != null) ...[
                        const SizedBox(height: 18),
                        _EventPeriod(notice: notice),
                      ],
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: AppDesignTokens.divider),
                      const SizedBox(height: 24),
                      LinkifyText(
                        text: notice.content,
                        style: const TextStyle(
                          color: AppDesignTokens.navy,
                          fontSize: 15,
                          height: 1.7,
                        ),
                      ),
                      if (notice.imageUrls case final images?
                          when images.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        for (final image in images)
                          _NoticeImage(
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
                            '${notice.commentCount}',
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
                        source: CommentSource.notice,
                        postId: notice.id,
                      ),
                    ],
                  ),
                ),
              ),
              CommentComposer(source: CommentSource.notice, postId: notice.id),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editNotice(BuildContext context, WidgetRef ref) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoticeFormScreen(notice: notice)),
    );
    if (updated != true || !context.mounted) return;
    ref.invalidate(noticesProvider);
    Navigator.pop(context, true);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('공지사항 삭제'),
        content: const Text('이 공지사항을 삭제하시겠습니까?'),
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
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(noticeNotifierProvider).deleteNotice(notice.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공지사항이 삭제되었습니다.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $error')));
    }
  }
}

class _NoticeMeta extends StatelessWidget {
  const _NoticeMeta({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final important = notice.noticeType == 'NOTICE';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: important
                ? AppDesignTokens.coral.withValues(alpha: 0.1)
                : AppDesignTokens.paleBlue,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            important ? '중요 공지' : '일반 공지',
            style: TextStyle(
              color: important ? AppDesignTokens.coral : AppDesignTokens.blue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _gradeLabel(notice.targetGrade),
          style: const TextStyle(
            color: AppDesignTokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          _formatDate(notice.createdAt),
          style: const TextStyle(color: AppDesignTokens.subtle, fontSize: 12),
        ),
      ],
    );
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
  const _AuthorRow({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppDesignTokens.paleBlue,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.campaign_outlined,
            size: 19,
            color: AppDesignTokens.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            notice.authorName,
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
          '${notice.viewCount}',
          style: const TextStyle(color: AppDesignTokens.subtle, fontSize: 12),
        ),
      ],
    );
  }
}

class _EventPeriod extends StatelessWidget {
  const _EventPeriod({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final start = notice.eventStartDate!;
    final end = notice.eventEndDate ?? start;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignTokens.paleBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 19,
            color: AppDesignTokens.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              start == end ? start : '$start ~ $end',
              style: const TextStyle(
                color: AppDesignTokens.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeImage extends StatelessWidget {
  const _NoticeImage({
    required this.url,
    required this.images,
    required this.onOpen,
  });

  final String url;
  final List<String> images;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final imageUrl = getCleanImageUrl(url);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(images.indexOf(url)),
          child: Image.network(
            imageUrl,
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
