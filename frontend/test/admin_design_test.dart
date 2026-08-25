import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/models/admin_request.dart';
import 'package:y_sync/models/community_post.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/providers/admin_member_provider.dart';
import 'package:y_sync/providers/admin_provider.dart';
import 'package:y_sync/providers/community_provider.dart';
import 'package:y_sync/screens/admin_dashboard_screen.dart';

class _TestAdminMemberNotifier extends AdminMemberNotifier {
  @override
  AdminMemberState build() => AdminMemberState(
    members: [_member],
    totalElements: 1,
    totalPages: 1,
    currentPage: 0,
    isLoading: false,
  );

  @override
  Future<void> fetchMembers({
    int page = 0,
    int size = 15,
    String? search,
  }) async {}
}

class _TestAdminNotifier extends AdminNotifier {
  @override
  Future<List<AdminRequest>> build() async => [_request];

  @override
  Future<void> fetchPendingRequests() async {}
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

final _request = AdminRequest(
  id: 1,
  requesterName: '김관리',
  loginId: '2405001',
  reason: '학과 공지와 학생 계정을 관리하기 위해 신청합니다.',
  status: 'PENDING',
  requestedAt: DateTime(2026, 8, 25).toIso8601String(),
);

final _post = CommunityPost(
  id: 1,
  category: 'QA',
  title: '관리 대상 게시글',
  content: '게시글 내용입니다.',
  anonymous: false,
  authorName: '배진수',
  memberId: 1,
  createdAt: DateTime(2026, 8, 25).toIso8601String(),
);

void main() {
  testWidgets('관리자 모바일 화면은 회원·승인·콘텐츠를 짧은 탭으로 전환한다', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('관리자'), findsOneWidget);
    expect(find.text('CSV 등록'), findsOneWidget);
    expect(find.text(_member.name), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('권한 승인'));
    await tester.pumpAndSettle();
    expect(find.text(_request.requesterName), findsOneWidget);
    expect(find.text('승인'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('콘텐츠'));
    await tester.pumpAndSettle();
    expect(find.text('전체'), findsOneWidget);
    expect(find.text(_post.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('관리자 데스크톱 화면은 사이드바와 작업 영역을 분리한다', (tester) async {
    _setViewport(tester, const Size(1200, 800));
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('관리자 콘솔'), findsOneWidget);
    expect(find.text('회원 관리'), findsNWidgets(2));
    expect(find.text('관리자 종료'), findsOneWidget);
    expect(find.text(_member.loginId), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp() => ProviderScope(
  overrides: [
    adminMemberProvider.overrideWith(_TestAdminMemberNotifier.new),
    adminProvider.overrideWith(_TestAdminNotifier.new),
    communityPostsProvider.overrideWith((ref) async => [_post]),
    adminReportsProvider.overrideWith((ref) async => []),
  ],
  child: const MaterialApp(home: AdminDashboardScreen()),
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
