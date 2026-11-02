import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/widgets/browser_notification_permission_card.dart';

void main() {
  const titles = {
    'granted': '브라우저 알림 허용됨',
    'denied': '브라우저 알림 차단됨',
    'default': '브라우저 알림 허용 필요',
    'unsupported': '이 환경에서는 알림을 지원하지 않습니다',
    'unknown': '브라우저 알림 상태를 확인하지 못했습니다',
  };
  for (final entry in titles.entries) {
    testWidgets('${entry.key}: 좁은 화면과 큰 글자에서 권한 안내 표시', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserNotificationPermissionProvider.overrideWith(
              (ref) => entry.key,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: const SingleChildScrollView(
                  child: BrowserNotificationPermissionCard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('수동 재확인과 앱 복귀 시 현재 권한을 다시 읽는다', (tester) async {
    var permission = 'default';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browserNotificationPermissionProvider.overrideWith(
            (ref) => permission,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BrowserNotificationPermissionCard()),
        ),
      ),
    );
    expect(find.text(titles['default']!), findsOneWidget);
    permission = 'denied';
    await tester.tap(find.text('권한 상태 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text(titles['denied']!), findsOneWidget);
    permission = 'granted';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text(titles['granted']!), findsOneWidget);
  });
}
