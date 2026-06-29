import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../screens/deep_link_loading_screen.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final themeColor = const Color(0xFF164687); // Y-Sync 브랜드 로열 블루

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '알림 센터',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        actions: [
          notificationsAsync.maybeWhen(
            data: (list) => list.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.done_all_rounded),
                    tooltip: '모두 읽음 표시',
                    onPressed: () async {
                      final hasUnread = list.any((n) => !n.isRead);
                      if (!hasUnread) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('읽지 않은 알림이 없습니다.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      await ref.read(notificationsProvider.notifier).markAllAsRead();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('모든 알림을 읽음 처리했습니다.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
            },
            color: themeColor,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildDismissibleItem(context, ref, notification, themeColor);
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF164687)),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                '알림을 불러오는 중 오류가 발생했습니다.\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '수신된 알림이 없습니다.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 학사 공지나 댓글 소식이 있으면\n이곳에 보관됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleItem(
    BuildContext context,
    WidgetRef ref,
    dynamic notification,
    Color themeColor,
  ) {
    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        ref.read(notificationsProvider.notifier).deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림이 삭제되었습니다.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.redAccent, Colors.red],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(notification.isRead ? 0.02 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: notification.isRead 
                ? Colors.transparent 
                : themeColor.withOpacity(0.12),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              // 1. 미읽음 상태인 경우 읽음 처리 API 호출
              if (!notification.isRead) {
                await ref
                    .read(notificationsProvider.notifier)
                    .markAsRead(notification.id);
              }

              // 2. 딥링크를 활용해 해당 리소스로 안전하게 텔레포트 라우팅
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeepLinkLoadingScreen(
                      targetType: notification.targetType,
                      targetId: notification.targetId.toString(),
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 알림 상태에 따른 원형 아이콘
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: notification.isRead
                          ? Colors.grey.shade100
                          : themeColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notification.targetType == 'NOTICE'
                          ? Icons.campaign_rounded
                          : Icons.chat_bubble_outline_rounded,
                      color: notification.isRead ? Colors.grey : themeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              notification.targetType == 'NOTICE' ? '학사공지' : '댓글 알림',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: notification.isRead
                                    ? Colors.grey
                                    : themeColor.withOpacity(0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _formatTime(notification.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notification.isRead 
                                ? FontWeight.normal 
                                : FontWeight.bold,
                            color: notification.isRead ? Colors.grey.shade600 : Colors.black87,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: notification.isRead ? Colors.grey.shade500 : Colors.black54,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return '방금 전';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}일 전';
      } else {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return isoString;
    }
  }
}
