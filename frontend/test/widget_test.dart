import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/main.dart';

void main() {
  testWidgets('로그인하지 않은 사용자는 로그인 화면으로 이동한다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: YSyncApp()));
    await tester.pumpAndSettle();

    expect(find.text('Y-Sync'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('회원가입하기'), findsOneWidget);
  });
}
