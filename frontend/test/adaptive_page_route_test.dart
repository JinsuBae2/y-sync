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

  for (final startX in [21.0, 22.0, 31.0]) {
    testWidgets('PWA 상세는 $startX px에서 복귀하고 본문 여백을 유지한다', (tester) async {
      final key = GlobalKey<NavigatorState>();
      EdgeInsets? contentPadding;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: const Scaffold(body: Text('list')),
        ),
      );
      key.currentState!.push(
        PwaCupertinoPageRoute<void>(
          builder: (context) {
            contentPadding = MediaQuery.paddingOf(context);
            return const Scaffold(body: Text('detail'));
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(contentPadding, EdgeInsets.zero);
      final gesture = await tester.startGesture(Offset(startX, 300));
      await gesture.moveBy(const Offset(600, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsNothing);
      expect(find.text('list'), findsOneWidget);
    });
  }

  testWidgets('PWA 가장자리 짧은 드래그는 취소하고 중앙·세로 드래그는 복귀하지 않는다', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: Text('list')),
      ),
    );
    key.currentState!.push(
      PwaCupertinoPageRoute<void>(
        builder: (_) => Scaffold(
          body: ListView(
            controller: scroll,
            children: const [SizedBox(height: 2000, child: Text('detail'))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(22, 300));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    await tester.dragFrom(const Offset(100, 300), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    await tester.dragFrom(const Offset(22, 500), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(key.currentState!.canPop(), true);
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
