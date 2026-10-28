import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/screens/community_form_screen.dart';
import 'package:y_sync/screens/notice_form_screen.dart';

void main() {
  for (final notice in [true, false]) {
    testWidgets('${notice ? '공지' : '커뮤니티'}: 키보드 위 등록 버튼과 닫힌 뒤 위치 유지', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: notice
                ? const NoticeFormScreen()
                : const CommunityFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(
        FilledButton,
        notice ? '공지 등록' : '게시글 등록',
      );
      final original = tester.getRect(button);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(512));
      expect(tester.getTopLeft(button).dy, greaterThan(kToolbarHeight));
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(tester.getRect(button), original);
      // Browsers that resize the viewport expose no separate keyboard inset.
      tester.view.physicalSize = const Size(375, 512);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(512));
      expect(tester.getBottomRight(button).dy, greaterThan(450));
    });
  }
}
