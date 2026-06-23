import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice.dart';
import '../models/comment.dart';
import '../providers/notice_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/comment_provider.dart';
import 'notice_form_screen.dart';
import '../widgets/deletion_reason_dialog.dart';
import '../utils/image_url_helper.dart';
import '../widgets/image_viewer_screen.dart';

class NoticeDetailScreen extends ConsumerWidget {
  final Notice notice;

  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentMember = authState.asData?.value;
    
    // Check if the current user is the author or an admin
    final canEdit = currentMember != null && 
        (currentMember.role == 'ADMIN' || currentMember.name == notice.authorName || currentMember.loginId == notice.authorName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항 상세'),
        actions: canEdit ? [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '수정',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NoticeFormScreen(notice: notice),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '삭제',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ] : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: notice.noticeType == 'OFFICIAL' ? Colors.red.shade500 : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            notice.noticeType,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: notice.noticeType == 'OFFICIAL' ? Colors.white : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      Text(
                        _formatDate(notice.createdAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    notice.title,
                    style: const TextStyle(
                      fontSize: 26, 
                      fontWeight: FontWeight.w900,
                      height: 1.4,
                      letterSpacing: -0.5,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                        child: Icon(Icons.person_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        notice.authorName, 
                        style: const TextStyle(
                          color: Colors.black87, 
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 32),
                  Text(
                    notice.content,
                    style: const TextStyle(
                      fontSize: 16, 
                      height: 1.6,
                      letterSpacing: -0.2,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (notice.imageUrls != null && notice.imageUrls!.isNotEmpty) ...[
                    ...notice.imageUrls!.map((url) {
                      final imageUrl = getCleanImageUrl(url);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageViewerScreen(
                                  imageUrls: notice.imageUrls!.map((u) => getCleanImageUrl(u)).toList(),
                                  initialIndex: notice.imageUrls!.indexOf(url),
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: Colors.grey.shade100,
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: double.infinity,
                                height: 150,
                                color: Colors.grey.shade100,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('이미지를 불러올 수 없습니다.', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 32),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.chat_bubble_rounded, size: 18, color: Theme.of(context).colorScheme.secondary),
                      ),
                      const SizedBox(width: 10),
                      const Text('댓글', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 16),
                  _CommentList(source: CommentSource.notice, id: notice.id),
                ],
              ),
            ),
          ),
          _CommentInputArea(source: CommentSource.notice, id: notice.id),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('공지사항 삭제'),
        content: const Text('정말로 이 공지사항을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(noticeNotifierProvider).deleteNotice(notice.id);
                if (context.mounted) {
                  Navigator.pop(context); // Go back to list screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('삭제되었습니다.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: $e')),
                  );
                }
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
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

class _CommentList extends ConsumerWidget {
  final CommentSource source;
  final int id;

  const _CommentList({required this.source, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(commentsProvider((source: source, id: id)));
    final authState = ref.watch(authProvider);
    final currentMember = authState.asData?.value;

    return commentsAsync.when(
      data: (comments) {
        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('첫 번째 댓글을 남겨보세요!', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 💡 최상위 부모 댓글 타일
                _buildCommentTile(context, ref, comment, currentMember, isSubComment: false),
                
                // 💡 자식 대댓글 목록 들여쓰기 렌더링
                if (comment.children != null && comment.children!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 28.0, top: 4.0, bottom: 8.0),
                    child: Column(
                      children: comment.children!.map((child) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildCommentTile(context, ref, child, currentMember, isSubComment: true),
                        );
                      }).toList(),
                    ),
                  ),
                const Divider(height: 1, color: Colors.black12),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (e, st) => Center(child: Text('댓글 로딩 에러: $e')),
    );
  }

  Widget _buildCommentTile(
    BuildContext context,
    WidgetRef ref,
    Comment comment,
    Member? currentMember, {
    required bool isSubComment,
  }) {
    final isAdmin = currentMember?.role == 'ADMIN' || currentMember?.role == 'SUPER_ADMIN';
    final isMyComment = currentMember != null && 
        (currentMember.name == comment.authorName || currentMember.loginId == comment.authorName);
    final canDelete = (isMyComment || isAdmin) && !comment.isDeleted;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isSubComment ? const Color(0xFF164687).withOpacity(0.02) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSubComment) ...[
            const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
          ],
          CircleAvatar(
            radius: 16,
            backgroundColor: comment.isDeleted ? Colors.grey.shade200 : Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              comment.isDeleted ? '-' : (comment.authorName.isNotEmpty ? comment.authorName.substring(0, 1).toUpperCase() : '?'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.isDeleted ? '익명' : comment.authorName, 
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(comment.createdAt),
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: comment.isDeleted
                        ? Colors.red.shade50
                        : (isMyComment 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.08) 
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.zero,
                      topRight: const Radius.circular(16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    comment.isDeleted ? '관리자에 의해 삭제된 댓글입니다.' : comment.content, 
                    style: TextStyle(
                      color: comment.isDeleted ? Colors.red.shade300 : Colors.black87, 
                      height: 1.4, 
                      fontSize: 14,
                      fontStyle: comment.isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 💡 부모 댓글일 때만 [답글] 버튼을 노출합니다.
              if (!isSubComment && !comment.isDeleted && currentMember != null)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    // 답글 대상 지정
                    ref.read(activeParentCommentProvider(id).notifier).state = comment;
                  },
                  child: const Text('답글', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF164687))),
                ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.black45),
                  onPressed: () => _confirmDeleteComment(context, ref, comment, isAdmin),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(BuildContext context, WidgetRef ref, Comment comment, bool isAdmin) async {
    if (isAdmin) {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => const DeletionReasonDialog(),
      );
      if (reason == null) return;

      try {
        await ref.read(commentNotifierProvider).deleteCommentByAdmin(source, id, comment.id, reason);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('관리자 권한으로 삭제되었습니다.')));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('댓글 삭제'),
          content: const Text('정말로 삭제하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(commentNotifierProvider).deleteComment(source, id, comment.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
                  }
                } catch (e) {
            ),
          ],
        ),
      );
    }
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

class _CommentInputArea extends ConsumerStatefulWidget {
  final CommentSource source;
  final int id;

  const _CommentInputArea({required this.source, required this.id});

  @override
  ConsumerState<_CommentInputArea> createState() => _CommentInputAreaState();
}

class _CommentInputAreaState extends ConsumerState<_CommentInputArea> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  void _submitComment(Comment? activeParent) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(commentNotifierProvider).createComment(
            widget.source,
            widget.id,
            text,
            parentId: activeParent?.id, // 💡 대댓글 parentId 주입
          );
      _controller.clear();
      // 답글 모드 리셋
      ref.read(activeParentCommentProvider(widget.id).notifier).state = null;
      FocusScope.of(context).unfocus(); // Close keyboard
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 작성 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeParent = ref.watch(activeParentCommentProvider(widget.id));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 💡 답글 작성 대상 표시 인디케이터 바
        if (activeParent != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF164687).withOpacity(0.08),
            child: Row(
              children: [
                const Icon(Icons.reply_rounded, size: 16, color: Color(0xFF164687)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${activeParent.authorName}님에게 답글 작성 중...',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF164687)),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // 답글 취소
                    ref.read(activeParentCommentProvider(widget.id).notifier).state = null;
                  },
                  child: const Icon(Icons.cancel_rounded, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -2),
                blurRadius: 10,
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: activeParent != null ? '답글을 입력하세요...' : '댓글을 입력하세요...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isSubmitting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary, // Amber color for unified theme
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: Colors.black87,
                        iconSize: 20,
                        onPressed: () => _submitComment(activeParent),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
},
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded),
                    color: Colors.black87,
                    iconSize: 20,
                    onPressed: _submitComment,
                  ),
                ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
