import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/utils/adaptive_page_route.dart';
import 'package:y_sync/widgets/app_root_back_guard.dart';

void main() {
  testWidgets('PWA 루트는 시스템 뒤로가기를 처리하고 탭 드래그와 상세 복귀는 유지한다', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: AppRootBackGuard(
          enabled: true,
          child: Scaffold(
            body: PageView(
              children: const [
                Center(child: Text('first')),
                Center(child: Text('second')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(await tester.binding.handlePopRoute(), true);
    expect(
      platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
      isEmpty,
    );
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('second').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.text('first').hitTestable(), findsOneWidget);
    key.currentState!.push(
      CupertinoPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(5, 300));
    await gesture.moveBy(const Offset(600, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    expect(find.text('first').hitTestable(), findsOneWidget);
    key.currentState!.push(
      adaptivePageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')),
      ),
    );
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), true);
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    expect(
      platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
      isEmpty,
    );
  });

  testWidgets('PWA 외에서는 루트 뒤로가기 기본 동작을 유지한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppRootBackGuard(
          enabled: false,
          child: Scaffold(body: Text('root')),
        ),
      ),
    );
    final context = tester.element(find.text('root'));
    expect(await Navigator.of(context).maybePop(), false);
  });
}
