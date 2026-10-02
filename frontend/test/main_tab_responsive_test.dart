import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:y_sync/models/community_post.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/models/my_comment.dart';
import 'package:y_sync/models/notice.dart';
import 'package:y_sync/providers/auth_provider.dart';
import 'package:y_sync/providers/calendar_provider.dart';
import 'package:y_sync/providers/community_provider.dart';
import 'package:y_sync/providers/home_provider.dart';
import 'package:y_sync/providers/mypage_provider.dart';
import 'package:y_sync/providers/notice_feed_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/providers/scrap_provider.dart';
import 'package:y_sync/providers/timetable_provider.dart';
import 'package:y_sync/screens/main_tab_screen.dart';

final _member = Member(
  id: 1,
  loginId: '2305009',
  name: '학생',
  role: 'USER',
  noticeEnabled: true,
  commentEnabled: true,
  isActivated: true,
);

class _Auth extends AuthNotifier {
  @override
  Future<Member?> build() async => _member;
}

class _Profile extends MyPageNotifier {
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
    posts: <CommunityPost>[],
    comments: <MyComment>[],
    notices: null,
  );
}

class _Feed extends NoticeFeedNotifier {
  @override
  Future<NoticeFeedState> build() async => const NoticeFeedState();
}

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('화면 폭을 바꿔도 선택 탭과 본문이 일치한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          myPageProvider.overrideWith(_Profile.new),
          noticeFeedProvider.overrideWith(_Feed.new),
          unreadNotificationCountProvider.overrideWithValue(0),
          homeNoticesProvider.overrideWith((ref) async => []),
          homeCalendarEventsProvider.overrideWith((ref) async => []),
          homeCommunityPostsProvider.overrideWith((ref) async => []),
          communityPostsProvider.overrideWith((ref) async => []),
          scrapsProvider.overrideWith((ref) async => []),
          calendarEventsProvider.overrideWith((ref) async => []),
          timetableEntriesProvider.overrideWith((ref) async => []),
          personalTimetableEntriesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: MainTabScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('내정보').last);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    await tester.tap(find.text('내정보').first);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 4);
    expect(find.text('내 활동과 계정 설정을 관리하세요').hitTestable(), findsOneWidget);

    await tester.tap(find.text('내정보').last);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 4);

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    await tester.tap(find.text('커뮤니티').first);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 2);
    expect(tester.takeException(), isNull);
  });
}
