import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification.dart';
import '../providers/notification_provider.dart';
import '../theme/app_design_tokens.dart';
import 'deep_link_loading_screen.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          '알림',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: [
          notificationsAsync.maybeWhen(
            data: (notifications) =>
                notifications.any((notification) => !notification.isRead)
                ? IconButton(
                    tooltip: '모두 읽음',
                    onPressed: () => _markAllAsRead(context, ref),
                    icon: const Icon(Icons.done_all_rounded),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
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
          child: notificationsAsync.when(
            data: (notifications) => notifications.isEmpty
                ? const _EmptyNotifications()
                : _NotificationList(notifications: notifications),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppDesignTokens.blue),
            ),
            error: (_, _) => _NotificationError(
              onRetry: () => ref.invalidate(notificationsProvider),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref) async {
    await ref.read(notificationsProvider.notifier).markAllAsRead();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('모든 알림을 읽음 처리했습니다.')));
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.notifications});

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = notifications
        .where((notification) => !notification.isRead)
        .length;

    return RefreshIndicator(
      color: AppDesignTokens.blue,
      onRefresh: () async => ref.invalidate(notificationsProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            unreadCount == 0 ? '새로운 알림이 없습니다' : '읽지 않은 알림 $unreadCount개',
            style: const TextStyle(
              color: AppDesignTokens.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < notifications.length; index++) ...[
            _NotificationRow(notification: notifications[index]),
            if (index < notifications.length - 1)
              const Divider(height: 1, color: AppDesignTokens.divider),
          ],
        ],
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNotice = notification.targetType == 'NOTICE';

    return Dismissible(
      key: ValueKey('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref
            .read(notificationsProvider.notifier)
            .deleteNotification(notification.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('알림이 삭제되었습니다.')));
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppDesignTokens.coral,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: notification.isRead
            ? Colors.transparent
            : AppDesignTokens.paleBlue.withValues(alpha: 0.38),
        child: InkWell(
          onTap: () => _openNotification(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppDesignTokens.divider),
                  ),
                  child: Icon(
                    isNotice
                        ? Icons.campaign_outlined
                        : Icons.chat_bubble_outline_rounded,
                    color: notification.isRead
                        ? AppDesignTokens.muted
                        : AppDesignTokens.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isNotice ? '공지' : '댓글',
                            style: TextStyle(
                              color: notification.isRead
                                  ? AppDesignTokens.muted
                                  : AppDesignTokens.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!notification.isRead) ...[
                            const SizedBox(width: 7),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppDesignTokens.coral,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            _formatTime(notification.createdAt),
                            style: const TextStyle(
                              color: AppDesignTokens.subtle,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: notification.isRead
                              ? AppDesignTokens.muted
                              : AppDesignTokens.navy,
                          fontSize: 15,
                          fontWeight: notification.isRead
                              ? FontWeight.w600
                              : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppDesignTokens.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(BuildContext context, WidgetRef ref) async {
    if (!notification.isRead) {
      await ref
          .read(notificationsProvider.notifier)
          .markAsRead(notification.id);
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeepLinkLoadingScreen(
          targetType: notification.targetType,
          targetId: '${notification.targetId}',
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 42,
            color: AppDesignTokens.subtle,
          ),
          SizedBox(height: 16),
          Text(
            '도착한 알림이 없습니다',
            style: TextStyle(
              color: AppDesignTokens.navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '새 공지와 내 글의 댓글 소식을 이곳에서 확인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppDesignTokens.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '알림을 불러오지 못했습니다.',
          style: TextStyle(color: AppDesignTokens.muted),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('다시 시도'),
        ),
      ],
    ),
  );
}

String _formatTime(String value) {
  try {
    final date = DateTime.parse(value);
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return '방금 전';
    if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
    if (difference.inHours < 24) return '${difference.inHours}시간 전';
    if (difference.inDays < 7) return '${difference.inDays}일 전';
    return '${date.month}.${date.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return value;
  }
}
