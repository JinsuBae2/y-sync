import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/widgets/app_confirmation_dialog.dart';
import 'package:y_sync/widgets/deletion_reason_dialog.dart';

void main() {
  testWidgets('320px·글자 2배의 긴 안내도 스크롤하여 취소와 확인에 접근한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('열기'),
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AppConfirmationDialog(
                    title: '학생 탈퇴 처리',
                    primaryActionIndex: 0,
                    content: Text('계정 정보가 지워지고 다시 로그인할 수 없게 됩니다. ' * 8),
                    actions: [
                      AppDialogAction(
                        label: '취소',
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      AppDialogAction(
                        label: '탈퇴 처리',
                        destructive: true,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('취소'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, false);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('탈퇴 처리'));
    await tester.tap(find.text('탈퇴 처리'));
    await tester.pumpAndSettle();
    expect(result, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('관리자 삭제는 취소가 주 동작이며 사유 없이는 실행되지 않는다', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const DeletionReasonDialog(),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(FilledButton, '취소'), findsOneWidget);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.byType(DeletionReasonDialog), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('광고/스팸'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(result, '광고/스팸');
    expect(find.byType(DeletionReasonDialog), findsNothing);
  });
}
