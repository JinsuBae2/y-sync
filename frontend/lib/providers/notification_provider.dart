import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification.dart';
import 'api_client_provider.dart';
import 'session_provider.dart';
import 'demo_access_provider.dart';

class NotificationNotifier extends AsyncNotifier<List<AppNotification>> {
  static const pageSize = 20;
  int? _memberId;
  int? _unreadCount;
  String? _cursor;
  int _generation = 0;
  int _revision = 0;
  int _loadedCount = pageSize;
  bool isLoadingMore = false;
  bool loadMoreFailed = false;
  bool get hasNext => _cursor != null;
  int get unreadCount =>
      _unreadCount ?? state.value?.where((n) => !n.isRead).length ?? 0;

  @override
  Future<List<AppNotification>> build() async {
    final memberId = ref.watch(sessionMemberIdProvider);
    if (_memberId != memberId) {
      _loadedCount = pageSize;
      _unreadCount = 0;
      _cursor = null;
    }
    _memberId = memberId;
    final generation = ++_generation;
    isLoadingMore = false;
    loadMoreFailed = false;
    if (memberId == null) return const [];
    final items = <AppNotification>[];
    final ids = <int>{};
    String? cursor;
    int count = 0;
    do {
      final revision = _revision;
      final page = await _fetch(cursor);
      if (!ref.mounted || generation != _generation) return const [];
      // 조회 도중 읽음/삭제가 완료되면 그 이전 응답을 버리고 다시 동기화합니다.
      if (revision != _revision) {
        items.clear();
        ids.clear();
        cursor = null;
        continue;
      }
      items.addAll(page.items.where((n) => ids.add(n.id)));
      cursor = page.cursor;
      count = page.unreadCount;
      if (cursor == null || items.length >= _loadedCount) break;
    } while (true);
    _cursor = cursor;
    _unreadCount = count;
    _loadedCount = items.length;
    return items;
  }

  Future<({List<AppNotification> items, String? cursor, int unreadCount})>
  _fetch(String? cursor) async {
    final response = await ref
        .read(dioProvider)
        .get(
          '/notifications/feed',
          queryParameters: {'size': pageSize, 'cursor': ?cursor},
        );
    final data = response.data as Map<String, dynamic>;
    return (
      items: (data['items'] as List)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList(),
      cursor: data['hasNext'] == true ? data['nextCursor'] as String? : null,
      unreadCount: (data['unreadCount'] as num).toInt(),
    );
  }

  Future<void> loadMore() async {
    if (state.value == null || state.isLoading || isLoadingMore || !hasNext) {
      return;
    }
    final generation = _generation;
    final revision = _revision;
    isLoadingMore = true;
    loadMoreFailed = false;
    state = AsyncData(List.of(state.requireValue));
    try {
      final page = await _fetch(_cursor);
      if (!ref.mounted || generation != _generation || state.isLoading) return;
      isLoadingMore = false;
      if (revision != _revision) {
        state = AsyncData(List.of(state.requireValue));
        return;
      }
      final current = state.requireValue;
      final ids = current.map((n) => n.id).toSet();
      final merged = [...current, ...page.items.where((n) => ids.add(n.id))];
      _cursor = page.cursor;
      _unreadCount = page.unreadCount;
      _loadedCount = merged.length;
      state = AsyncData(merged);
    } catch (_) {
      if (!ref.mounted || generation != _generation || state.isLoading) return;
      isLoadingMore = false;
      loadMoreFailed = true;
      state = AsyncData(List.of(state.requireValue));
    }
  }

  Future<void> refresh() async {
    _loadedCount = pageSize;
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // 최초 조회 실패는 화면의 재시도 안내로 표시합니다.
    }
  }

  Future<void> markAllAsRead() async {
    if (ref.read(isDemoAccountProvider)) return;
    final memberId = ref.read(sessionMemberIdProvider);
    await ref.read(dioProvider).put('/notifications/read');
    if (!ref.mounted || memberId != ref.read(sessionMemberIdProvider)) return;
    _revision++;
    _unreadCount = 0;
    state = state.whenData(
      (list) => list.map((n) => n.copyWith(isRead: true)).toList(),
    );
  }

  Future<void> markAsRead(int notificationId) async {
    if (ref.read(isDemoAccountProvider)) return;
    final memberId = ref.read(sessionMemberIdProvider);
    try {
      await ref.read(dioProvider).put('/notifications/$notificationId/read');
      if (!ref.mounted || memberId != ref.read(sessionMemberIdProvider)) return;
      _revision++;
      final wasUnread =
          state.value?.any((n) => n.id == notificationId && !n.isRead) ?? false;
      if (wasUnread && unreadCount > 0) _unreadCount = unreadCount - 1;
      state = state.whenData(
        (list) => list
            .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
            .toList(),
      );
    } catch (_) {
      if (ref.mounted && memberId == ref.read(sessionMemberIdProvider)) {
        ref.invalidateSelf();
      }
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    final memberId = ref.read(sessionMemberIdProvider);
    try {
      await ref.read(dioProvider).delete('/notifications/$notificationId');
      if (!ref.mounted || memberId != ref.read(sessionMemberIdProvider)) return;
      _revision++;
      final wasUnread =
          state.value?.any((n) => n.id == notificationId && !n.isRead) ?? false;
      if (wasUnread && unreadCount > 0) _unreadCount = unreadCount - 1;
      state = state.whenData(
        (list) => list.where((n) => n.id != notificationId).toList(),
      );
    } catch (_) {
      if (ref.mounted && memberId == ref.read(sessionMemberIdProvider)) {
        ref.invalidateSelf();
      }
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationNotifier, List<AppNotification>>(() {
      return NotificationNotifier();
    });

// 페이지에 없는 알림도 포함한 전체 미읽음 개수입니다.
final unreadNotificationCountProvider = Provider<int>((ref) {
  ref.watch(notificationsProvider);
  return ref.read(notificationsProvider.notifier).unreadCount;
});
