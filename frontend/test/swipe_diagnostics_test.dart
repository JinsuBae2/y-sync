import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/utils/swipe_diagnostics.dart';

void main() {
  test('목록 요청은 내용과 식별자를 제외한 고정 분류만 기록한다', () {
    expect(swipeListCategory('/notices?keyword=private'), 'notice');
    expect(swipeListCategory('/community/search?keyword=private'), 'community');
    expect(swipeListCategory('/notices/123'), isNull);
    expect(swipeListCategory('/auth/login'), isNull);
    expect(swipeListCategory('/members/me'), isNull);
  });

  testWidgets('진단 observer는 화면 내용 없이 이동과 제스처 순서만 기록한다', (tester) async {
    final events = <String>[];
    final observer = SwipeDiagnosticsObserver(
      record: (event, detail) {
        expect(detail, isEmpty);
        events.add(event);
      },
    );
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('list')),
      ),
    );
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/private/123'),
      builder: (_) => const Scaffold(body: Text('private content')),
    );
    key.currentState!.push(route);
    await tester.pumpAndSettle();
    observer.didStartUserGesture(route, null);
    observer.didStopUserGesture();
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(events, [
      'route_push',
      'route_push',
      'gesture_start',
      'gesture_stop',
      'route_pop',
    ]);
    expect(find.text('list'), findsOneWidget);
  });
}
