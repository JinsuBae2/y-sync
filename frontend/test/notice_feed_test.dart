import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/models/community_post.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/models/my_comment.dart';
import 'package:y_sync/models/notice.dart';
import 'package:y_sync/providers/api_client_provider.dart';
import 'package:y_sync/providers/mypage_provider.dart';
import 'package:y_sync/providers/notice_feed_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/providers/scrap_provider.dart';
import 'package:y_sync/screens/notice_list_screen.dart';

/// 💡 공지 피드(커서 무한 스크롤)를 고정하는 테스트입니다.
///
/// 이전에는 목록이 서버 기본 20건에서 끊기고 더 볼 수단이 없어, 21번째 공지부터는
/// DB에 있어도 학생이 도달할 수 없었습니다.

Notice _notice(int id) => Notice(
  id: id,
  title: '공지 $id',
  content: '내용 $id',
  authorName: '관리자',
  noticeType: 'NOTICE',
  createdAt: DateTime(2026, 9, 1).toIso8601String(),
  targetGrade: 'ALL',
  isPinned: false,
  viewCount: 0,
  commentCount: 0,
  attachments: const [],
);

/// 커서 한 번에 10건씩 두 페이지를 주는 가짜 서버입니다.
class _FakeFeedAdapter implements HttpClientAdapter {
  final List<String> requestedPaths = [];
  final List<String?> requestedCursors = [];
  int newCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);

    if (options.path.contains('feed-updates')) {
      return _json({'newCount': newCount});
    }

    final cursor = options.queryParameters['cursor'] as String?;
    requestedCursors.add(cursor);

    // 첫 페이지: 1~10 + 다음 커서. 두 번째: 11~15 + 끝.
    final isFirstPage = cursor == null;
    final ids = isFirstPage
        ? List<int>.generate(10, (index) => 100 - index)
        : List<int>.generate(5, (index) => 90 - index);

    return _json({
      'pinned': isFirstPage ? [_noticeJson(999, pinned: true)] : [],
      'items': ids.map((id) => _noticeJson(id)).toList(),
      'nextCursor': isFirstPage ? 'CURSOR-2' : null,
      'hasNext': isFirstPage,
      'latestId': 100,
    });
  }

  Map<String, dynamic> _noticeJson(int id, {bool pinned = false}) => {
    'id': id,
    'title': '공지 $id',
    'content': '내용 $id',
    'authorName': '관리자',
    'noticeType': 'NOTICE',
    'createdAt': DateTime(2026, 9, 1).toIso8601String(),
    'targetGrade': 'ALL',
    'isPinned': pinned,
    'viewCount': 0,
    'commentCount': 0,
    'attachments': <dynamic>[],
  };

  ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _TestMyPageNotifier extends MyPageNotifier {
  @override
  Future<
    ({
      Member member,
      List<CommunityPost> posts,
      List<MyComment> comments,
      List<Notice>? notices,
    })
  >
  build() async => (
    member: Member(
      id: 1,
      loginId: '2305001',
      name: '학생',
      role: 'USER',
      noticeEnabled: true,
      commentEnabled: true,
      isActivated: true,
    ),
    posts: const <CommunityPost>[],
    comments: const <MyComment>[],
    notices: null,
  );
}

/// 화면 없이 Notifier만 돌리기 위한 컨테이너입니다.
ProviderContainer _container(_FakeFeedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(dio)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('커서 피드 Notifier', () {
    test('첫 페이지는 고정 공지와 일반 공지를 나눠 담는다', () async {
      final container = _container(_FakeFeedAdapter());

      final feed = await container.read(noticeFeedProvider.future);

      expect(feed.pinned.map((n) => n.id), [999]);
      expect(feed.items, hasLength(10));
      expect(feed.hasNext, isTrue);
      expect(feed.latestId, 100);
      // 고정 공지가 항상 맨 위입니다.
      expect(feed.visibleNotices.first.id, 999);
    });

    test('더 불러오면 커서를 넘기고 목록 뒤에 이어 붙인다', () async {
      final adapter = _FakeFeedAdapter();
      final container = _container(adapter);
      await container.read(noticeFeedProvider.future);

      await container.read(noticeFeedProvider.notifier).loadMore();
      final feed = container.read(noticeFeedProvider).value!;

      expect(adapter.requestedCursors, [null, 'CURSOR-2']);
      expect(feed.items, hasLength(15));
      expect(feed.items.map((n) => n.id).toSet(), hasLength(15)); // 중복 없음
      expect(feed.hasNext, isFalse);
      expect(feed.nextCursor, isNull);
    });

    test('마지막 페이지에 도달하면 더 요청하지 않는다', () async {
      final adapter = _FakeFeedAdapter();
      final container = _container(adapter);
      await container.read(noticeFeedProvider.future);

      final notifier = container.read(noticeFeedProvider.notifier);
      await notifier.loadMore(); // 2페이지 → hasNext=false
      final requestsAfterLastPage = adapter.requestedCursors.length;

      await notifier.loadMore();
      await notifier.loadMore();

      expect(adapter.requestedCursors, hasLength(requestsAfterLastPage));
    });

    test('새 공지 수는 목록을 건드리지 않고 newCount만 올린다', () async {
      final adapter = _FakeFeedAdapter()..newCount = 3;
      final container = _container(adapter);
      final before = await container.read(noticeFeedProvider.future);

      await container.read(noticeFeedProvider.notifier).checkForNewNotices();
      final after = container.read(noticeFeedProvider).value!;

      expect(after.newCount, 3);
      expect(after.items.map((n) => n.id), before.items.map((n) => n.id));
    });
  });

  group('공지 목록 화면', () {
    Future<void> pumpScreen(WidgetTester tester, _FakeFeedAdapter adapter) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            myPageProvider.overrideWith(_TestMyPageNotifier.new),
            scrapsProvider.overrideWith((ref) async => []),
            unreadNotificationCountProvider.overrideWithValue(0),
          ],
          child: const MaterialApp(home: NoticeListScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('바닥 가까이 스크롤하면 다음 페이지를 이어 받는다', (tester) async {
      final adapter = _FakeFeedAdapter();
      await pumpScreen(tester, adapter);

      expect(adapter.requestedCursors, [null]);

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();

      expect(adapter.requestedCursors, contains('CURSOR-2'));
      expect(find.text('마지막 공지입니다'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('새 공지가 있어도 최상단에서는 칩을 띄우지 않는다', (tester) async {
      final adapter = _FakeFeedAdapter()..newCount = 5;
      await pumpScreen(tester, adapter);

      await tester.element(find.byType(ListView));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NoticeListScreen)),
      );
      await container.read(noticeFeedProvider.notifier).checkForNewNotices();
      await tester.pumpAndSettle();

      // 최상단에서는 당겨서 새로고침이면 충분합니다.
      expect(find.byKey(const ValueKey('notice-new-chip')), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notice-new-chip')), findsOneWidget);
      expect(find.text('새 공지 5개'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
