import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/providers/api_client_provider.dart';
import 'package:y_sync/providers/auth_provider.dart';
import 'package:y_sync/providers/comment_provider.dart';
import 'package:y_sync/providers/scrap_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/providers/session_provider.dart';
import 'package:y_sync/screens/notification_center_screen.dart';

Map<String, dynamic> notification(int id) => {
  'id': id,
  'title': '알림 $id',
  'body': '알림 내용 $id',
  'targetType': 'COMMUNITY',
  'targetId': id,
  'isRead': false,
  'createdAt': '2026-11-02T09:00:00',
};
void main() {
  late ProviderContainer container;
  late List<Map<String, dynamic>> queries;
  late bool failMore;
  Completer<void>? releaseMore;
  Completer<void>? startedMore;
  setUp(() {
    failMore = false;
    releaseMore = null;
    startedMore = null;
    queries = [];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) async {
          if (o.path == '/notifications/feed') {
            queries.add(Map.of(o.queryParameters));
            final cursor = o.queryParameters['cursor'];
            if (cursor != null) {
              if (startedMore != null && !startedMore!.isCompleted) {
                startedMore!.complete();
              }
              if (releaseMore != null) await releaseMore!.future;
              if (failMore) {
                h.reject(DioException(requestOptions: o));
                return;
              }
            }
            final start = cursor == null ? 100 : int.parse(cursor as String);
            h.resolve(
              Response(
                requestOptions: o,
                data: {
                  'items': List.generate(20, (i) => notification(start - i)),
                  'nextCursor': start > 60 ? '${start - 20}' : null,
                  'hasNext': start > 60,
                  'unreadCount': 70,
                },
              ),
            );
          } else if (o.path.startsWith('/community/')) {
            final id = int.parse(o.path.split('/').last);
            h.resolve(
              Response(
                requestOptions: o,
                data: {
                  'id': id,
                  'title': '대상 글 $id',
                  'content': '글 내용',
                  'category': 'FREE',
                  'anonymous': false,
                  'authorName': '학생',
                  'memberId': 2,
                  'createdAt': '2026-11-02T09:00:00',
                },
              ),
            );
          } else {
            h.resolve(Response(requestOptions: o, data: {}));
          }
        },
      ),
    );
    container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        authProvider.overrideWithBuild((ref, n) async => null),
        commentsProvider.overrideWith((ref, arg) async => []),
        scrapsProvider.overrideWith((ref) async => []),
      ],
    );
    container.read(sessionMemberIdProvider.notifier).activate(1);
    container.listen(notificationsProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test('20개만 받아도 배지는 전체 미읽음 개수이며 읽음·삭제를 반영한다', () async {
    expect((await container.read(notificationsProvider.future)).length, 20);
    expect(container.read(unreadNotificationCountProvider), 70);
    final n = container.read(notificationsProvider.notifier);
    await n.markAsRead(100);
    expect(container.read(unreadNotificationCountProvider), 69);
    await n.markAsRead(100);
    expect(container.read(unreadNotificationCountProvider), 69);
    await n.deleteNotification(99);
    expect(container.read(unreadNotificationCountProvider), 68);
    await n.markAllAsRead();
    expect(container.read(unreadNotificationCountProvider), 0);
    expect(
      container.read(notificationsProvider).requireValue.every((n) => n.isRead),
      isTrue,
    );
  });
  test('추가 조회 실패는 기존 목록을 보존하고 같은 커서로 재시도한다', () async {
    await container.read(notificationsProvider.future);
    final n = container.read(notificationsProvider.notifier);
    failMore = true;
    await n.loadMore();
    expect(container.read(notificationsProvider).requireValue.length, 20);
    expect(n.loadMoreFailed, isTrue);
    failMore = false;
    await n.loadMore();
    expect(container.read(notificationsProvider).requireValue.length, 40);
    expect(queries.map((q) => q['cursor']), [null, '80', '80']);
    container.invalidate(notificationsProvider);
    expect((await container.read(notificationsProvider.future)).length, 40);
    await n.refresh();
    expect(container.read(notificationsProvider).requireValue.length, 20);
  });
  test('중복 조회를 막고 늦은 페이지가 읽음 상태를 되돌리지 않는다', () async {
    await container.read(notificationsProvider.future);
    final n = container.read(notificationsProvider.notifier);
    releaseMore = Completer();
    startedMore = Completer();
    final pending = n.loadMore();
    await startedMore!.future;
    await n.loadMore();
    expect(queries.length, 2);
    await n.markAllAsRead();
    releaseMore!.complete();
    await pending;
    expect(container.read(unreadNotificationCountProvider), 0);
    expect(container.read(notificationsProvider).requireValue.length, 20);
    expect(n.isLoadingMore, isFalse);
    expect(n.hasNext, isTrue);
  });
  test('로그아웃 뒤 늦게 도착한 페이지는 이전 계정 알림을 복원하지 않는다', () async {
    await container.read(notificationsProvider.future);
    final n = container.read(notificationsProvider.notifier);
    releaseMore = Completer();
    startedMore = Completer();
    final pending = n.loadMore();
    await startedMore!.future;
    container.read(sessionMemberIdProvider.notifier).clear();
    expect(await container.read(notificationsProvider.future), isEmpty);
    releaseMore!.complete();
    await pending;
    expect(container.read(notificationsProvider).requireValue, isEmpty);
    expect(container.read(unreadNotificationCountProvider), 0);
  });
  testWidgets('두 번째 페이지 알림의 글을 읽고 돌아와도 위치와 읽음 상태를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => container.read(notificationsProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('알림 75'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('알림 75')).dy;
    await tester.tap(find.text('알림 75'));
    await tester.pumpAndSettle();
    expect(find.text('대상 글 75'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('알림 75')).dy, closeTo(before, 1));
    expect(
      container
          .read(notificationsProvider)
          .requireValue
          .firstWhere((n) => n.id == 75)
          .isRead,
      isTrue,
    );
    expect(container.read(unreadNotificationCountProvider), 69);
    expect(tester.takeException(), isNull);
  });
  testWidgets('실패 안내에서 재시도하면 기존 알림 뒤에 다음 페이지를 붙인다', (tester) async {
    failMore = true;
    await tester.runAsync(() => container.read(notificationsProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('더 불러오지 못했습니다. 다시 시도'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(container.read(notificationsProvider).requireValue.length, 20);
    failMore = false;
    await tester.tap(find.text('더 불러오지 못했습니다. 다시 시도'));
    await tester.pumpAndSettle();
    expect(container.read(notificationsProvider).requireValue.length, 40);
  });
}
