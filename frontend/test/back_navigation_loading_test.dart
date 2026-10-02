import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/utils/back_navigation_loading.dart';

void main() {
  testWidgets('복귀 애니메이션 이후 캡처한 로딩 요청만 완료한다', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final finished = <int>[];
    var token = 1;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [
          BackNavigationLoadingObserver(
            capture: () => token,
            complete: finished.add,
          ),
        ],
        home: const Scaffold(body: Text('list')),
      ),
    );
    key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')),
      ),
    );
    await tester.pumpAndSettle();
    key.currentState!.pop();
    token = 2;
    expect(finished, isEmpty);
    await tester.pump();
    expect(finished, isEmpty);
    await tester.pumpAndSettle();
    expect(finished, [1]);
    expect(find.text('list'), findsOneWidget);
  });
}
