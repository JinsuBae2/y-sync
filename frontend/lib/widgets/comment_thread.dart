import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment.dart';
import '../models/member.dart';
import '../providers/auth_provider.dart';
import '../providers/comment_provider.dart';
import '../theme/app_design_tokens.dart';
import 'deletion_reason_dialog.dart';

class CommentListSection extends ConsumerWidget {
  const CommentListSection({
    super.key,
    required this.source,
    required this.postId,
    this.onReport,
  });

  final CommentSource source;
  final int postId;
  final void Function(BuildContext context, int commentId)? onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(
      commentsProvider((source: source, id: postId)),
    );
    final member = ref.watch(authProvider).asData?.value;

    return commentsAsync.when(
      data: (comments) {
        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 34),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 32,
                  color: AppDesignTokens.subtle,
                ),
                SizedBox(height: 10),
                Text(
                  '아직 댓글이 없습니다.',
                  style: TextStyle(
                    color: AppDesignTokens.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (var index = 0; index < comments.length; index++) ...[
              _CommentItem(
                source: source,
                postId: postId,
                comment: comments[index],
                member: member,
                onReport: onReport,
              ),
              if (comments[index].children case final replies?
                  when replies.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 24),
                  padding: const EdgeInsets.only(left: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppDesignTokens.divider),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (final reply in replies)
                        _CommentItem(
                          source: source,
                          postId: postId,
                          comment: reply,
                          member: member,
                          isReply: true,
                          onReport: onReport,
                        ),
                    ],
                  ),
                ),
              if (index != comments.length - 1)
                const Divider(height: 1, color: AppDesignTokens.divider),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            color: AppDesignTokens.blue,
            strokeWidth: 2,
          ),
        ),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            '댓글을 불러오지 못했습니다.',
            style: TextStyle(color: AppDesignTokens.muted),
          ),
        ),
      ),
    );
  }
}

class _CommentItem extends ConsumerWidget {
  const _CommentItem({
    required this.source,
    required this.postId,
    required this.comment,
    required this.member,
    required this.onReport,
    this.isReply = false,
  });

  final CommentSource source;
  final int postId;
  final Comment comment;
  final Member? member;
  final void Function(BuildContext context, int commentId)? onReport;
  final bool isReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = member?.role == 'ADMIN' || member?.role == 'SUPER_ADMIN';
    final isMine = member != null && member!.id == comment.memberId;
    final canDelete = !comment.isDeleted && (isMine || isAdmin);
    final canReport =
        member != null && !isMine && !comment.isDeleted && onReport != null;
    final authorName = comment.isDeleted ? '삭제된 댓글' : comment.authorName;
    final deletedByAdmin = comment.deletedBy == CommentDeletedBy.admin;
    final deletedMessage = deletedByAdmin
        ? '관리자에 의해 삭제된 댓글입니다.'
        : '작성자가 삭제한 댓글입니다.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: comment.isDeleted
                  ? AppDesignTokens.background
                  : AppDesignTokens.paleBlue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              comment.isDeleted || comment.authorName.isEmpty
                  ? '-'
                  : comment.authorName.characters.first,
              style: TextStyle(
                color: comment.isDeleted
                    ? AppDesignTokens.subtle
                    : AppDesignTokens.blue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppDesignTokens.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _shortDate(comment.createdAt),
                      style: const TextStyle(
                        color: AppDesignTokens.subtle,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.isDeleted ? deletedMessage : comment.content,
                  style: TextStyle(
                    color: comment.isDeleted
                        ? deletedByAdmin
                              ? AppDesignTokens.coral
                              : AppDesignTokens.subtle
                        : AppDesignTokens.navy,
                    fontSize: 14,
                    height: 1.45,
                    fontStyle: comment.isDeleted
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                if ((!isReply && !comment.isDeleted && member != null) ||
                    canDelete ||
                    canReport) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (!isReply && !comment.isDeleted && member != null)
                        TextButton(
                          onPressed: () => ref
                              .read(activeParentCommentProvider.notifier)
                              .updateState(postId, comment),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            '답글',
                            style: TextStyle(
                              color: AppDesignTokens.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (canDelete) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _deleteComment(
                            context,
                            ref,
                            isAdmin: isAdmin,
                            isMine: isMine,
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            '삭제',
                            style: TextStyle(
                              color: AppDesignTokens.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (canReport) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => onReport!(context, comment.id),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            '신고',
                            style: TextStyle(
                              color: AppDesignTokens.coral,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(
    BuildContext context,
    WidgetRef ref, {
    required bool isAdmin,
    required bool isMine,
  }) async {
    try {
      if (isMine) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('댓글 삭제'),
            content: const Text('이 댓글을 삭제하시겠습니까?'),
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
        await ref
            .read(commentNotifierProvider)
            .deleteComment(source, postId, comment.id);
      } else if (isAdmin) {
        final reason = await showDialog<String>(
          context: context,
          builder: (_) => const DeletionReasonDialog(),
        );
        if (reason == null) return;
        await ref
            .read(commentNotifierProvider)
            .deleteCommentByAdmin(source, postId, comment.id, reason);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글이 삭제되었습니다.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('댓글 삭제 실패: $error')));
    }
  }

  static String _shortDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.split('T').first;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month.$day $hour:$minute';
  }
}

class CommentComposer extends ConsumerStatefulWidget {
  const CommentComposer({
    super.key,
    required this.source,
    required this.postId,
  });

  final CommentSource source;
  final int postId;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(Comment? parent) async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(commentNotifierProvider)
          .createComment(
            widget.source,
            widget.postId,
            content,
            parentId: parent?.id,
          );
      _controller.clear();
      ref
          .read(activeParentCommentProvider.notifier)
          .updateState(widget.postId, null);
      if (mounted) FocusScope.of(context).unfocus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('댓글 작성 실패: $error')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = ref.watch(activeParentCommentProvider)[widget.postId];

    return Material(
      color: AppDesignTokens.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (parent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppDesignTokens.paleBlue,
              child: Row(
                children: [
                  const Icon(
                    Icons.reply_rounded,
                    size: 16,
                    color: AppDesignTokens.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${parent.authorName}님에게 답글 작성 중',
                      style: const TextStyle(
                        color: AppDesignTokens.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '답글 취소',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(activeParentCommentProvider.notifier)
                        .updateState(widget.postId, null),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppDesignTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              10 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppDesignTokens.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(
                      color: AppDesignTokens.navy,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: parent == null ? '댓글을 입력하세요' : '답글을 입력하세요',
                      hintStyle: const TextStyle(color: AppDesignTokens.subtle),
                      filled: true,
                      fillColor: AppDesignTokens.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppDesignTokens.divider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppDesignTokens.blue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton.filled(
                    tooltip: '댓글 등록',
                    onPressed: _isSubmitting ? null : () => _submit(parent),
                    style: IconButton.styleFrom(
                      backgroundColor: AppDesignTokens.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppDesignTokens.subtle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 19),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
