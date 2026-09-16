import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/utils/adaptive_page_route.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS는 가장자리 스와이프가 가능한 Cupertino 라우트를 사용한다', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final route = adaptivePageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );

    expect(route, isA<CupertinoPageRoute<void>>());
    expect(route.settings.name, isNull);
  });

  testWidgets('상세에서만 브라우저 제스처 차단을 켜고 다이얼로그와 복귀에서는 해제한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final active = <bool>[];
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [
          PwaDetailBackGestureObserver(setActive: active.add),
        ],
        home: const Scaffold(body: Text('list')),
      ),
    );
    key.currentState!.push(
      adaptivePageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')),
      ),
    );
    await tester.pumpAndSettle();
    expect(active.last, true);
    showDialog<void>(
      context: tester.element(find.text('detail')),
      builder: (_) => const AlertDialog(content: Text('dialog')),
    );
    await tester.pumpAndSettle();
    expect(active.last, false);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(active.last, true);
    final gesture = await tester.startGesture(const Offset(5, 300));
    await gesture.moveBy(const Offset(600, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(active.last, false);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.fuchsia,
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    test('$platform은 Material 라우트를 유지한다', () {
      debugDefaultTargetPlatformOverride = platform;

      final route = adaptivePageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
      );

      expect(route, isA<MaterialPageRoute<void>>());
    });
  }
}
