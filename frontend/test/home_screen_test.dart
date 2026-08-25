import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:y_sync/models/calendar_event.dart';
import 'package:y_sync/models/community_post.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/models/notice.dart';
import 'package:y_sync/providers/auth_provider.dart';
import 'package:y_sync/providers/home_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/screens/home_screen.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<Member?> build() async {
    return Member(
      id: 1,
      loginId: '2305009',
      name: '배진수',
      role: 'USER',
      noticeEnabled: true,
      commentEnabled: true,
      isActivated: true,
    );
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  testWidgets('홈은 개인 시간표 없이 핵심 공지와 공통 정보를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final eventDate = now.add(const Duration(days: 2));
    final deadline = now.add(const Duration(days: 5));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          unreadNotificationCountProvider.overrideWithValue(1),
          homeNoticesProvider.overrideWith(
            (ref) async => [
              Notice(
                id: 1,
                title: '2학기 수강신청 및 개강 안내',
                content: '필독 공지 내용',
                authorName: '관리자',
                noticeType: 'NOTICE',
                createdAt: now.toIso8601String(),
                isPinned: true,
                eventStartDate: _apiDate(deadline),
              ),
              Notice(
                id: 2,
                title: '2025-2학기 장학금 신청 안내',
                content: '장학금 안내 내용',
                authorName: '관리자',
                noticeType: 'NEWS',
                createdAt: now.toIso8601String(),
              ),
            ],
          ),
          homeCalendarEventsProvider.overrideWith(
            (ref) async => [
              CalendarEvent(
                id: 1,
                title: '2학기 수강신청 마감',
                startDate: _apiDate(eventDate),
                endDate: _apiDate(eventDate),
                type: 'ACADEMIC',
                color: '#246BFD',
              ),
            ],
          ),
          homeCommunityPostsProvider.overrideWith(
            (ref) async => [
              CommunityPost(
                id: 1,
                category: 'QA',
                title: '모프 3주차 과제 관련 질문입니다!',
                content: '질문 내용',
                anonymous: true,
                authorName: '익명의 학생',
                memberId: 1,
                createdAt: now.toIso8601String(),
                viewCount: 20,
                commentCount: 3,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          home: HomeScreen(
            onOpenNotices: () {},
            onOpenCommunity: () {},
            onOpenSchedule: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('안녕하세요, 배진수님'), findsOneWidget);
    expect(find.text('2학기 수강신청 및 개강 안내'), findsOneWidget);
    expect(find.text('다가오는 학사일정'), findsOneWidget);
    expect(find.text('오늘 수업'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('최근 공지'), findsOneWidget);
    expect(find.text('커뮤니티 인기글'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _apiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
