import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/models/community_post.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/models/my_comment.dart';
import 'package:y_sync/models/notice.dart';
import 'package:y_sync/models/notification.dart';
import 'package:y_sync/models/scrap.dart';
import 'package:y_sync/providers/mypage_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/providers/scrap_provider.dart';
import 'package:y_sync/screens/auth_settings_screen.dart';
import 'package:y_sync/screens/my_comments_screen.dart';
import 'package:y_sync/screens/my_posts_screen.dart';
import 'package:y_sync/screens/notification_center_screen.dart';
import 'package:y_sync/screens/notification_settings_screen.dart';
import 'package:y_sync/screens/scrap_list_screen.dart';

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
    member: _member,
    posts: <CommunityPost>[_post],
    comments: <MyComment>[_comment],
    notices: null,
  );
}

class _TestNotificationNotifier extends NotificationNotifier {
  @override
  Future<List<AppNotification>> build() async => [_notification];
}

final _member = Member(
  id: 1,
  loginId: '2305009',
  name: '배진수',
  role: 'USER',
  noticeEnabled: false,
  commentEnabled: true,
  isActivated: true,
);

final _post = CommunityPost(
  id: 1,
  category: 'QA',
  title: '캡스톤 프로젝트 관련 질문',
  content: '프로젝트 제출 형식을 확인하고 싶습니다.',
  anonymous: false,
  authorName: '배진수',
  memberId: 1,
  createdAt: DateTime(2026, 8, 25).toIso8601String(),
  viewCount: 20,
  commentCount: 2,
);

final _comment = MyComment(
  id: 2,
  content: '제출 안내를 확인했습니다.',
  postTitle: _post.title,
  category: 'QA',
  postId: _post.id,
  createdAt: DateTime(2026, 8, 25).toIso8601String(),
);

final _scrap = Scrap(
  scrapId: 1,
  targetType: 'COMMUNITY',
  targetId: _post.id,
  category: 'QA',
  title: _post.title,
  authorName: _post.authorName,
  postCreatedAt: DateTime(2026, 8, 25),
  commentCount: 2,
  scrappedAt: DateTime(2026, 8, 25),
);

final _notification = AppNotification(
  id: 1,
  title: '새 댓글이 달렸습니다',
  body: '캡스톤 프로젝트 관련 질문에 답변이 등록되었습니다.',
  targetType: 'COMMUNITY',
  targetId: _post.id,
  isRead: false,
  createdAt: DateTime.now().toIso8601String(),
);

void main() {
  testWidgets('스크랩 목록은 글 종류와 메타 정보를 구분한다', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scrapsProvider.overrideWith((ref) async => [_scrap]),
        ],
        child: const MaterialApp(home: ScrapListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('스크랩한 글'), findsOneWidget);
    expect(find.text(_scrap.title), findsOneWidget);
    expect(find.byTooltip('스크랩 해제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('내 글과 댓글 화면은 원문 이동 정보를 표시한다', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(MaterialApp(home: MyPostsScreen(posts: [_post])));
    await tester.pumpAndSettle();

    expect(find.text('내가 쓴 게시글'), findsOneWidget);
    expect(find.text(_post.title), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [myPageProvider.overrideWith(_TestMyPageNotifier.new)],
        child: const MaterialApp(home: MyCommentsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('내가 남긴 댓글'), findsOneWidget);
    expect(find.text(_comment.content), findsOneWidget);
    expect(find.text(_comment.postTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('알림 센터는 읽지 않은 알림을 우선 표시한다', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(_TestNotificationNotifier.new),
        ],
        child: const MaterialApp(home: NotificationCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('읽지 않은 알림 1개'), findsOneWidget);
    expect(find.text(_notification.title), findsOneWidget);
    expect(find.byTooltip('모두 읽음'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('알림 설정은 서버의 회원 설정값을 반영한다', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [myPageProvider.overrideWith(_TestMyPageNotifier.new)],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.map((widget) => widget.value), [false, true]);
    expect(find.text('수신할 알림'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('보안 설정은 모바일 폭에서 주요 인증 수단을 표시한다', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthSettingsScreen())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('보안 및 간편 로그인'), findsOneWidget);
    expect(find.text('생체 인식'), findsOneWidget);
    expect(find.text('PIN 로그인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
