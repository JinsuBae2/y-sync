import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/models/attachment.dart';
import 'package:y_sync/widgets/attachment_file_tile.dart';

const filename = '2026학년도_팀프로젝트_최종발표자료.pdf';
Widget screen({String url = 'https://example.com/file?token=test'}) =>
    MaterialApp(
      home: Scaffold(
        body: AttachmentFileTile(
          attachment: Attachment(
            url: url,
            originalFilename: filename,
            isImage: false,
          ),
        ),
      ),
    );

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  testWidgets('실패 파일명을 표시하고 사용자 재시도로 같은 주소를 연다', (tester) async {
    final urls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      urls.add((call.arguments as Map)['url'] as String);
      return urls.length > 1;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(screen());
    await tester.tap(find.text(filename));
    await tester.pumpAndSettle();
    expect(find.text('첨부파일을 열지 못했습니다'), findsOneWidget);
    expect(find.text(filename), findsNWidgets(2));
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(urls.length, 2);
    expect(urls.first, urls.last);
    expect(Uri.parse(urls.last).queryParameters, {
      'token': 'test',
      'name': filename,
    });
    expect(find.text('첨부파일을 열지 못했습니다'), findsNothing);
  });
  testWidgets('플랫폼 예외도 안내하고 닫을 수 있다', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'failed'),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(screen());
    await tester.tap(find.text(filename));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('첨부파일을 열지 못했습니다'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('첨부파일을 열지 못했습니다'), findsNothing);
  });
  testWidgets('잘못된 주소도 처리되지 않은 예외를 남기지 않는다', (tester) async {
    await tester.pumpWidget(screen(url: 'http://[invalid'));
    await tester.tap(find.text(filename));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('첨부파일을 열지 못했습니다'), findsOneWidget);
    expect(find.textContaining('파일 주소가 올바르지 않습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });
  testWidgets('요청 중 화면이 닫히면 실패창을 띄우지 않는다', (tester) async {
    final result = Completer<bool>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) => result.future,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(screen());
    await tester.tap(find.text(filename));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    result.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('첨부파일을 열지 못했습니다'), findsNothing);
  });
}
