import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/providers/api_client_provider.dart';
import 'package:y_sync/providers/auth_provider.dart';
import 'package:y_sync/providers/community_provider.dart';
import 'package:y_sync/providers/comment_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/providers/session_provider.dart';
import 'package:y_sync/screens/community_list_screen.dart';
import 'package:y_sync/screens/splash_screen.dart';
import 'package:y_sync/widgets/comment_thread.dart';

class DemoAuth extends AuthNotifier {
  @override
  Future<Member?> build() async => Member.fromJson({
    'id': 99, 'loginId': 'demo', 'name': '데모', 'role': 'DEMO', 'activated': true,
  });
}

class FailingAuth extends AuthNotifier {
  @override
  Future<Member?> build() async => throw StateError('server unavailable');
}

void main() {
  testWidgets('데모는 목록과 검색을 볼 수 있지만 글쓰기 동작은 없다', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(DemoAuth.new),
        communityPostsProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: CommunityListScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('데모 댓글은 내용을 읽을 수 있지만 작성 입력은 제공하지 않는다', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(DemoAuth.new)],
      child: const MaterialApp(home: Scaffold(body: CommentComposer(source: CommentSource.community, postId: 1))),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('데모 계정에서는 변경할 수 없습니다.'), findsOneWidget);
  });

  test('데모 알림 읽음은 서버 요청과 로컬 상태 변경 없이 끝난다', () async {
    final calls = <String>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls.add(options.method);
      handler.resolve(Response(requestOptions: options, data: options.method == 'GET' ? [
        {'id': 1, 'title': '공지', 'body': '내용', 'targetType': 'NOTICE', 'targetId': 1,
         'isRead': false, 'createdAt': '2026-10-06T00:00:00'},
      ] : null));
    }));
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio), authProvider.overrideWith(DemoAuth.new),
    ]);
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    container.read(sessionMemberIdProvider.notifier).activate(99);
    await container.read(notificationsProvider.future);
    await container.read(notificationsProvider.notifier).markAsRead(1);
    await container.read(notificationsProvider.notifier).markAllAsRead();
    expect(calls, ['GET']);
    expect(container.read(notificationsProvider).requireValue.single.isRead, false);
  });
  test('데모 변경 요청은 Dio에서 차단하고 조회와 로그아웃은 허용한다', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'fixture'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(sessionMemberIdProvider.notifier).activate(99, isDemo: true);
    final dio = container.read(dioProvider);
    final calls = <String>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls.add('${options.method} ${options.path}');
      handler.resolve(Response(requestOptions: options, data: {}));
    }));
    await expectLater(dio.post('/community'), throwsA(isA<DioException>().having(
      (e) => e.response?.statusCode, 'status', 403,
    )));
    await dio.get('/community');
    await dio.post('/auth/logout');
    expect(calls, ['GET /community', 'POST /auth/logout']);
    container.read(sessionMemberIdProvider.notifier).clear();
    expect(container.read(sessionIsDemoProvider), false);
    await dio.post('/community');
    expect(calls.last, 'POST /community');
  });

  testWidgets('데모 여부 확인 중 인증 조회가 실패해도 시작 화면에서 예외를 던지지 않는다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fixture', 'has_seen_pin_setup': 'true',
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(FailingAuth.new)],
      child: const MaterialApp(home: SplashScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
