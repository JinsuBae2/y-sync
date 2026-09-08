import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:y_sync/models/calendar_event.dart';
import 'package:y_sync/models/community_post.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/models/my_comment.dart';
import 'package:y_sync/models/notice.dart';
import 'package:y_sync/models/timetable_entry.dart';
import 'package:y_sync/providers/auth_provider.dart';
import 'package:y_sync/providers/calendar_provider.dart';
import 'package:y_sync/providers/community_provider.dart';
import 'package:y_sync/providers/mypage_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/providers/scrap_provider.dart';
import 'package:y_sync/providers/timetable_provider.dart';
import 'package:y_sync/screens/community_list_screen.dart';
import 'package:y_sync/screens/academic_calendar_view.dart';
import 'package:y_sync/screens/profile_screen.dart';
import 'package:y_sync/screens/schedule_tab_screen.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<Member?> build() async => _member;
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
  build() async =>
      (member: _member, posts: [_post], comments: [_comment], notices: null);
}

final _member = Member(
  id: 1,
  loginId: '2305009',
  name: '배진수',
  role: 'USER',
  noticeEnabled: true,
  commentEnabled: true,
  isActivated: true,
);

final _post = CommunityPost(
  id: 1,
  category: 'QA',
  title: '캡스톤 프로젝트 팀원 모집',
  content: '프론트엔드 개발 경험이 있는 팀원을 찾습니다.',
  anonymous: false,
  authorName: '배진수',
  memberId: 1,
  createdAt: DateTime.now().toIso8601String(),
  viewCount: 24,
  commentCount: 3,
);

final _imagePost = CommunityPost(
  id: 2,
  category: 'FREE',
  title: '이미지 미리보기 게시글',
  content: '썸네일이 있어도 하단 액션이 같은 위치에 표시됩니다.',
  anonymous: false,
  authorName: '배진수',
  memberId: 1,
  createdAt: DateTime.now().toIso8601String(),
  viewCount: 5,
  commentCount: 1,
  imageUrls: const ['https://example.com/community-preview.png'],
);

final _comment = MyComment(
  id: 1,
  content: '참여하고 싶습니다.',
  postTitle: _post.title,
  category: 'QA',
  postId: _post.id,
  createdAt: DateTime.now().toIso8601String(),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  testWidgets('커뮤니티는 구분된 카드와 정렬된 즐겨찾기를 표시한다', (tester) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityPostsProvider.overrideWith(
            (ref) async => [_imagePost, _post],
          ),
          scrapsProvider.overrideWith((ref) async => []),
          unreadNotificationCountProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(home: CommunityListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('제목이나 내용 검색'), findsOneWidget);
    expect(find.text('전체 학년'), findsOneWidget);
    expect(find.text(_imagePost.title), findsOneWidget);
    expect(find.text(_post.title), findsOneWidget);

    final imageBookmark = tester.getRect(
      find.byKey(const ValueKey('community-post-bookmark-2')),
    );
    final plainBookmark = tester.getRect(
      find.byKey(const ValueKey('community-post-bookmark-1')),
    );
    final thumbnail = tester.getRect(
      find.byKey(const ValueKey('community-post-thumbnail-2')),
    );
    final imageCard = tester.getRect(
      find.byKey(const ValueKey('community-post-2')),
    );
    final plainCard = tester.getRect(
      find.byKey(const ValueKey('community-post-1')),
    );

    expect(imageBookmark.right, closeTo(plainBookmark.right, 0.1));
    expect(imageBookmark.center.dx, greaterThan(thumbnail.center.dx));
    expect(imageCard.bottom, lessThan(plainCard.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('일정은 학사 달력과 시간표를 한 화면에서 전환한다', (tester) async {
    _setMobileViewport(tester);
    final today = DateTime.now();
    final apiDate = _date(today);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          calendarEventsProvider.overrideWith(
            (ref) async => [
              CalendarEvent(
                id: 1,
                title: '수강신청 마감',
                startDate: apiDate,
                endDate: apiDate,
                color: '#FF5733',
                type: 'ACADEMIC',
              ),
            ],
          ),
          timetableEntriesProvider.overrideWith(
            (ref) async => [
              TimetableEntry(
                id: 1,
                grade: 'GRADE_1',
                dayOfWeek: 'MONDAY',
                subjectName: '모바일 프로그래밍',
                professorName: '김교수',
                classroom: '공학관 301호',
                startPeriod: 1,
                endPeriod: 2,
              ),
              TimetableEntry(
                id: 3,
                grade: 'GRADE_1',
                dayOfWeek: 'TUESDAY',
                subjectName: '데이터베이스',
                professorName: '이교수',
                classroom: '데이터베이스실습실',
                startPeriod: 3,
                endPeriod: 4,
              ),
            ],
          ),
          personalTimetableEntriesProvider.overrideWith(
            (ref) async => [
              TimetableEntry(
                id: 2,
                grade: 'PERSONAL',
                dayOfWeek: 'TUESDAY',
                subjectName: '내 선택 과목',
                professorName: '',
                classroom: '온라인',
                startPeriod: 3,
                endPeriod: 4,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: ScheduleTabScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('수강신청 마감'), findsOneWidget);
    final marker = tester.widget<Container>(
      find.byKey(const ValueKey('calendar-event-marker-1')),
    );
    final markerDecoration = marker.decoration! as BoxDecoration;
    expect(markerDecoration.color, const Color(0xFFFF5733));
    final accent = tester.widget<Container>(
      find.byKey(const ValueKey('calendar-event-accent-1')),
    );
    final accentDecoration = accent.decoration! as BoxDecoration;
    expect(accentDecoration.color, const Color(0xFFFF5733));
    final eventList = tester.widget<ListView>(
      find.byKey(const ValueKey('calendar-event-list')),
    );
    expect(eventList.padding, const EdgeInsets.fromLTRB(20, 12, 20, 116));
    final lastDay = DateTime(today.year, today.month + 1, 0).day.toString();
    final lastDateBottom = tester.getBottomLeft(find.text(lastDay).last).dy;
    final eventHeaderTop = tester
        .getTopLeft(find.text('${today.month}월 ${today.day}일 일정'))
        .dy;
    expect(lastDateBottom, lessThan(eventHeaderTop));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('시간표'));
    await tester.pumpAndSettle();

    expect(find.text('학과 시간표'), findsOneWidget);
    expect(find.text('개인 시간표'), findsOneWidget);
    expect(find.text('1학년'), findsOneWidget);
    expect(find.text('1반'), findsOneWidget);
    expect(find.text('2반'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timetable-day-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-timetable-day-list')),
      findsOneWidget,
    );
    expect(find.text('모바일 프로그래밍'), findsOneWidget);
    expect(find.text('09:00 - 11:00'), findsOneWidget);
    expect(find.text('공학관 301호'), findsOneWidget);
    expect(find.text('김교수 교수'), findsOneWidget);

    await tester.tap(find.text('주간'));
    await tester.pumpAndSettle();
    expect(find.text('9:00'), findsOneWidget);
    expect(find.textContaining('am'), findsNothing);
    expect(find.textContaining('pm'), findsNothing);

    await tester.tap(find.text('개인 시간표'));
    await tester.pumpAndSettle();

    expect(find.text('내 선택 과목'), findsOneWidget);
    expect(find.byTooltip('내 수업 추가'), findsOneWidget);
    await tester.tap(find.byTooltip('내 수업 추가'));
    await tester.pumpAndSettle();
    expect(find.text('학과 시간표에서 선택'), findsOneWidget);
    expect(find.text('직접 입력'), findsOneWidget);

    await tester.tap(find.text('학과 시간표에서 선택'));
    await tester.pumpAndSettle();
    expect(find.text('학년·반 선택'), findsOneWidget);
    await tester.tap(find.text('수업 보기'));
    await tester.pumpAndSettle();
    expect(find.text('1학년 1반 수업'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('department-course-1')));
    await tester.tap(find.byKey(const ValueKey('department-course-3')));
    await tester.pumpAndSettle();
    expect(find.text('선택한 수업 2개 추가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('데스크톱 일정 달력과 목록 너비를 분할선 드래그로 조절한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          calendarEventsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: AcademicCalendarView()),
      ),
    );
    await tester.pumpAndSettle();

    final panelFinder = find.byKey(const ValueKey('calendar-panel'));
    final handleFinder = find.byKey(const ValueKey('calendar-resize-handle'));
    final initialWidth = tester.getSize(panelFinder).width;

    expect(tester.getSize(handleFinder).width, 24);
    await tester.drag(handleFinder, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(tester.getSize(panelFinder).width, greaterThan(initialWidth + 80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 일정 달력과 목록을 한 화면에서 세로 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          calendarEventsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: AcademicCalendarView()),
      ),
    );
    await tester.pumpAndSettle();

    final pageFinder = find.byKey(
      const ValueKey('mobile-calendar-page-scroll'),
    );
    final eventHeaderFinder = find.textContaining('일 일정');
    final initialHeaderTop = tester.getTopLeft(eventHeaderFinder).dy;

    expect(pageFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-calendar-resize-handle')),
      findsNothing,
    );
    final scrollableFinder = find.descendant(
      of: pageFinder,
      matching: find.byType(Scrollable),
    );
    final scrollable = tester
        .stateList<ScrollableState>(scrollableFinder)
        .firstWhere(
          (state) =>
              state.position.axis == Axis.vertical &&
              state.position.maxScrollExtent > 0,
        );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(eventHeaderFinder).dy, lessThan(initialHeaderTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('내정보는 활동과 설정을 구분해 표시한다', (tester) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [myPageProvider.overrideWith(_TestMyPageNotifier.new)],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('내정보'), findsOneWidget);
    expect(find.text('배진수'), findsOneWidget);
    expect(find.text('내 활동'), findsOneWidget);
    expect(find.text('스크랩한 글'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

String _date(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
