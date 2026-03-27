import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_post.dart';
import '../models/comment.dart';
import '../providers/community_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/comment_provider.dart';
import '../widgets/deletion_reason_dialog.dart';

class CommunityDetailScreen extends ConsumerWidget {
  final CommunityPost post;

  const CommunityDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentMember = authState.asData?.value;
    
    // 본인이거나 ADMIN, SUPER_ADMIN인 경우 삭제 가능
    final isAdmin = currentMember != null && (currentMember.role == 'ADMIN' || currentMember.role == 'SUPER_ADMIN');
    final canDelete = currentMember != null && (isAdmin || currentMember.id == post.memberId);

    // 💡 삭제된 게시글 접근 예외 처리 (관리자가 아니면 빈 화면 표시)
    if (post.isDeleted && !isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${post.category} 게시글'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                '관리자에 의해 삭제된 게시글입니다.',
                style: TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.bold),
              ),
              if (post.deletionReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '사유: ${post.deletionReason}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('뒤로 가기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${post.category} 게시글'),
        actions: canDelete ? [
          IconButton(
            icon: const Icon(Icons.delete_outline),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            post.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      Text(
                        _formatDate(post.createdAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: post.anonymous ? Colors.grey.shade200 : Colors.amber.shade100,
                        child: Icon(
                          post.anonymous ? Icons.person_off_rounded : Icons.person_rounded,
                          size: 16,
                          color: post.anonymous ? Colors.grey : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        post.authorName, 
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text(
                    post.content,
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  if (post.imageUrls != null && post.imageUrls!.isNotEmpty) ...[
                    ...post.imageUrls!.map((url) {
                      final imageUrl = url.startsWith('/') 
                          ? 'http://10.0.2.2:8080$url' 
                          : url.replaceAll('localhost', '10.0.2.2');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
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
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Colors.black54),
                      const SizedBox(width: 8),
                      const Text('댓글', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CommentList(source: CommentSource.community, id: post.id),
                ],
              ),
            ),
          ),
          _CommentInputArea(source: CommentSource.community, id: post.id),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final authState = ref.read(authProvider).asData?.value;
    final isAdmin = authState != null && (authState.role == 'ADMIN' || authState.role == 'SUPER_ADMIN');

    if (isAdmin) {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => const DeletionReasonDialog(),
      );
      if (reason == null) return; // 취소

      try {
        await ref.read(communityNotifierProvider).deletePostByAdmin(post.id, reason);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('관리자 권한으로 삭제되었습니다.')));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('게시글 삭제'),
          content: const Text('정말로 이 게시글을 삭제하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(communityNotifierProvider).deletePost(post.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
                  }
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
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

// 💡 댓글 목록 UI (NoticeDetailScreen과 로직 동일)
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('첫 댓글을 남겨보세요!', style: TextStyle(color: Colors.grey))),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final comment = comments[index];
            final isAdmin = currentMember?.role == 'ADMIN' || currentMember?.role == 'SUPER_ADMIN';
            final isMyComment = currentMember != null && comment.authorName == currentMember.name;
            final canDelete = (isMyComment || isAdmin) && !comment.isDeleted;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: comment.isDeleted ? Colors.grey.shade200 : Colors.amber.shade100,
                  child: Text(
                    comment.isDeleted ? '-' : comment.authorName.substring(0, 1), 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(comment.isDeleted ? '익명' : comment.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Text(_formatDate(comment.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.isDeleted ? '관리자에 의해 삭제된 댓글입니다.' : comment.content, 
                        style: TextStyle(
                          fontSize: 14,
                          color: comment.isDeleted ? Colors.red.shade300 : Colors.black87,
                          fontStyle: comment.isDeleted ? FontStyle.italic : FontStyle.normal,
                        )
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () => _confirmDeleteComment(context, ref, comment, isAdmin),
                  ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Text('에러: $err'),
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('관리자 권한으로 삭제되었습니다.')));
        }
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
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}

// 💡 댓글 입력창 UI (NoticeDetailScreen과 로직 동일)
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

  void _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(commentNotifierProvider).createComment(widget.source, widget.id, text);
      _controller.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('댓글 작성 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: '댓글을 입력하세요...', border: InputBorder.none),
            ),
          ),
          _isSubmitting
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.secondary),
                  onPressed: _submit,
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
