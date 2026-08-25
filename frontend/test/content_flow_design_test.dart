import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/models/comment.dart';
import 'package:y_sync/models/community_post.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/models/my_comment.dart';
import 'package:y_sync/models/notice.dart';
import 'package:y_sync/providers/auth_provider.dart';
import 'package:y_sync/providers/comment_provider.dart';
import 'package:y_sync/providers/mypage_provider.dart';
import 'package:y_sync/providers/notice_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/providers/scrap_provider.dart';
import 'package:y_sync/screens/community_detail_screen.dart';
import 'package:y_sync/screens/community_form_screen.dart';
import 'package:y_sync/screens/notice_detail_screen.dart';
import 'package:y_sync/screens/notice_form_screen.dart';
import 'package:y_sync/screens/notice_list_screen.dart';

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
  build() async => (
    member: _member,
    posts: const <CommunityPost>[],
    comments: const <MyComment>[],
    notices: null,
  );
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

final _notice = Notice(
  id: 1,
  title: '2학기 수강신청 및 개강 안내',
  content: '수강신청 기간과 주의사항을 확인해주세요.',
  authorName: '관리자',
  noticeType: 'NOTICE',
  createdAt: DateTime(2026, 8, 25).toIso8601String(),
  targetGrade: 'ALL',
  isPinned: true,
  viewCount: 42,
  commentCount: 1,
);

final _post = CommunityPost(
  id: 2,
  category: 'QA',
  title: '모프 3주차 과제 관련 질문입니다',
  content: '실행 환경에서 발생하는 오류의 원인이 궁금합니다.',
  anonymous: true,
  authorName: '익명의 학생',
  memberId: 2,
  createdAt: DateTime(2026, 8, 25).toIso8601String(),
  targetGrade: 'GRADE_2',
  viewCount: 18,
  commentCount: 1,
);

final _comment = Comment(
  id: 3,
  content: '패키지 버전을 먼저 확인해보세요.',
  communityPostId: _post.id,
  memberId: 3,
  authorName: '김학생',
  createdAt: DateTime(2026, 8, 25).toIso8601String(),
);

void main() {
  testWidgets('공지 목록은 검색과 중요도를 먼저 보여준다', (tester) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticesProvider.overrideWith((ref) async => [_notice]),
          myPageProvider.overrideWith(_TestMyPageNotifier.new),
          scrapsProvider.overrideWith((ref) async => []),
          unreadNotificationCountProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(home: NoticeListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('공지 제목이나 내용 검색'), findsOneWidget);
    expect(find.text('고정'), findsOneWidget);
    expect(find.text(_notice.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('공지 상세는 본문과 댓글 흐름을 한 화면에 보여준다', (tester) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          commentsProvider.overrideWith((ref, arg) async => [_comment]),
        ],
        child: MaterialApp(home: NoticeDetailScreen(notice: _notice)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('중요 공지'), findsOneWidget);
    expect(find.text(_notice.content), findsOneWidget);
    expect(find.text('댓글을 입력하세요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('커뮤니티 상세는 신고와 댓글 동선을 제공한다', (tester) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          commentsProvider.overrideWith((ref, arg) async => [_comment]),
        ],
        child: MaterialApp(home: CommunityDetailScreen(post: _post)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_post.title), findsOneWidget);
    expect(find.byTooltip('게시글 신고'), findsOneWidget);
    expect(find.text(_comment.content), findsOneWidget);
    expect(find.text('댓글을 입력하세요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('공지와 커뮤니티 작성 화면은 모바일 폭에서 넘치지 않는다', (tester) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NoticeFormScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('공지사항 작성'), findsOneWidget);
    expect(find.text('기본 정보'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CommunityFormScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('게시글 작성'), findsOneWidget);
    expect(find.text('게시글 정보'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
