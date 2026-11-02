import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/widgets/upload_progress_label.dart';

void main() {
  testWidgets('준비, 전송률, 서버 저장을 구분하고 알 수 없는 크기는 비율을 만들지 않는다', (tester) async {
    Future<void> show({int? sent, int? total, bool files = true}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UploadProgressLabel(
                hasAttachments: files,
                sent: sent,
                total: total,
              ),
            ),
          ),
        );
    await show();
    expect(find.text('첨부파일 준비 중…'), findsOneWidget);
    await show(sent: 25, total: 100);
    expect(find.text('첨부파일 전송 중 25%'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      .25,
    );
    await show(sent: 99, total: 100);
    expect(find.text('첨부파일 전송 중 99%'), findsOneWidget);
    await show(sent: 100, total: 100);
    expect(find.text('서버에 저장 중…'), findsOneWidget);
    await show(sent: 50, total: -1);
    expect(find.text('첨부파일 전송 중…'), findsOneWidget);
    await show(files: false);
    expect(find.text('서버에 저장 중…'), findsOneWidget);
  });
}
