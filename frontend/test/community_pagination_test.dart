import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:y_sync/providers/auth_provider.dart';
import 'package:y_sync/providers/comment_provider.dart';
import 'package:y_sync/providers/scrap_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/screens/community_list_screen.dart';
import 'package:y_sync/providers/api_client_provider.dart';
import 'package:y_sync/providers/community_provider.dart';
import 'package:y_sync/providers/session_provider.dart';

Map<String, dynamic> post(int id) => {
  'id': id,
  'category': 'FREE',
  'title': '글 $id',
  'content': '내용',
  'anonymous': false,
  'memberId': 1,
  'authorName': '학생',
  'createdAt': '2026-11-02T09:00:00',
};

void main() {
  late Dio dio;
  late ProviderContainer container;
  late List<Map<String, dynamic>> queries;
  var failMore = false;
  Completer<void>? delayMore;
  Completer<void>? moreStarted;
  setUp(() {
    queries = [];
    failMore = false;
    delayMore = null;
    moreStarted = null;
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path != '/community/feed') {
            handler.resolve(
              Response(
                requestOptions: options,
                data: post(int.parse(options.path.split('/').last)),
              ),
            );
            return;
          }
          queries.add(Map.of(options.queryParameters));
          final cursor = options.queryParameters['cursor'];
          if (cursor != null) {
            if (moreStarted != null && !moreStarted!.isCompleted) {
              moreStarted!.complete();
            }
            if (delayMore != null) await delayMore!.future;
            if (failMore) {
              handler.reject(DioException(requestOptions: options));
              return;
            }
          }
          final offset = cursor == null ? 0 : int.parse(cursor as String);
          final filtered = options.queryParameters['keyword'] == '검색';
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'items': filtered
                    ? [post(999)]
                    : List.generate(20, (i) => post(100 - offset - i)),
                'hasNext': !filtered && offset < 40,
                'nextCursor': !filtered && offset < 40
                    ? '${offset + 20}'
                    : null,
              },
            ),
          );
        },
      ),
    );
    container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        authProvider.overrideWithBuild((ref, notifier) async => null),
        commentsProvider.overrideWith((ref, arg) async => []),
        scrapsProvider.overrideWith((ref) async => []),
        unreadNotificationCountProvider.overrideWithValue(0),
      ],
    );
    container.listen(communityPostsProvider, (_, _) {});
  });
  tearDown(() {
    container.dispose();
    dio.close();
  });

  test('추가 페이지 실패는 기존 목록을 보존하고 재시도는 같은 커서를 쓴다', () async {
    final initial = await container.read(communityPostsProvider.future);
    final notifier = container.read(communityPostsProvider.notifier);
    failMore = true;
    await notifier.loadMore();
    expect(container.read(communityPostsProvider).requireValue, initial);
    expect(notifier.loadMoreFailed, isTrue);
    failMore = false;
    await notifier.loadMore();
    expect(container.read(communityPostsProvider).requireValue.length, 40);
    expect(queries.skip(1).map((q) => q['cursor']), ['20', '20']);
    expect(notifier.loadMoreFailed, isFalse);
  });
  test('중복 요청을 막고 필터가 바뀐 뒤 늦게 도착한 페이지는 무시한다', () async {
    await container.read(communityPostsProvider.future);
    final notifier = container.read(communityPostsProvider.notifier);
    delayMore = Completer<void>();
    moreStarted = Completer<void>();
    final pending = notifier.loadMore();
    await moreStarted!.future;
    await notifier.loadMore();
    expect(queries.length, 2);
    container.read(communitySearchKeywordProvider.notifier).updateKeyword('검색');
    expect(
      (await container.read(communityPostsProvider.future)).single.id,
      999,
    );
    delayMore!.complete();
    await pending;
    expect(container.read(communityPostsProvider).requireValue.single.id, 999);
    expect(notifier.hasNext, isFalse);
  });
  test('상세 복귀 갱신은 읽은 페이지 범위를 유지하고 필터·새로고침은 첫 페이지로 돌아간다', () async {
    await container.read(communityPostsProvider.future);
    final notifier = container.read(communityPostsProvider.notifier);
    await notifier.loadMore();
    container.invalidate(communityPostsProvider);
    expect((await container.read(communityPostsProvider.future)).length, 40);
    expect(queries.take(4).map((q) => q['cursor']), [null, '20', null, '20']);
    await notifier.refresh();
    expect(container.read(communityPostsProvider).requireValue.length, 20);
    await notifier.loadMore();
    container.read(communityGradeProvider.notifier).updateGrade('GRADE_2');
    expect((await container.read(communityPostsProvider.future)).length, 20);
    expect(queries.last['grade'], 'GRADE_2');
    expect(queries.last['cursor'], isNull);
    container.read(sessionMemberIdProvider.notifier).activate(2);
    await container.read(communityPostsProvider.future);
    expect(queries.last['cursor'], isNull);
  });
  testWidgets('두 번째 페이지 상세 복귀 후 글과 스크롤 위치가 유지된다', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => container.read(communityPostsProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CommunityListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('글 65'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('글 65')).dy;
    expect(container.read(communityPostsProvider).requireValue.length, 40);
    await tester.tap(find.text('글 65'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('글 65')).dy, closeTo(before, 1));
    expect(queries.skip(2).map((q) => q['cursor']), [null, '20']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('추가 조회 실패 안내에서 재시도하면 기존 글 뒤에 이어 붙인다', (tester) async {
    failMore = true;
    await tester.runAsync(() => container.read(communityPostsProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CommunityListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('더 불러오지 못했습니다. 다시 시도'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(container.read(communityPostsProvider).requireValue.length, 20);
    failMore = false;
    await tester.tap(find.text('더 불러오지 못했습니다. 다시 시도'));
    await tester.pumpAndSettle();
    expect(container.read(communityPostsProvider).requireValue.length, 40);
    expect(container.read(communityPostsProvider).requireValue.first.id, 100);
  });
}
