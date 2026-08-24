import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import 'notice_provider.dart'; // dioProvider

class NotificationNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    return _fetchNotifications();
  }

  Future<List<AppNotification>> _fetchNotifications() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/notifications');
    final List<dynamic> data = response.data;
    return data.map((json) => AppNotification.fromJson(json)).toList();
  }

  // 💡 전체 읽음 처리
  Future<void> markAllAsRead() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/notifications/read');
      
      // 로컬 데이터 캐시 갱신
      state = const AsyncValue.loading();
      final freshData = await _fetchNotifications();
      state = AsyncValue.data(freshData);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // 💡 개별 알림 읽음 처리
  Future<void> markAsRead(int notificationId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/notifications/$notificationId/read');
      
      // 로컬 상태 즉시 변경하여 로딩 딜레이 방지
      state.whenData((list) {
        final updatedList = list.map((n) {
          if (n.id == notificationId) {
            return AppNotification(
              id: n.id,
              title: n.title,
              body: n.body,
              targetType: n.targetType,
              targetId: n.targetId,
              isRead: true,
              createdAt: n.createdAt,
            );
          }
          return n;
        }).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (e) {
      // 실패 시 데이터 강제 갱신
      ref.invalidateSelf();
    }
  }

  // 💡 개별 알림 삭제
  Future<void> deleteNotification(int notificationId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/notifications/$notificationId');

      // 로컬 리스트에서 즉시 제거하여 부드러운 반응성 보장
      state.whenData((list) {
        final updatedList = list.where((n) => n.id != notificationId).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (e) {
      ref.invalidateSelf();
    }
  }
}

final notificationsProvider = AsyncNotifierProvider<NotificationNotifier, List<AppNotification>>(() {
  return NotificationNotifier();
});

// 💡 미읽음 알림 개수 계산을 위한 Provider
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  return notificationsAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
