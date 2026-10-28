import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/utils/attachment_selection_issue.dart';
import 'package:y_sync/widgets/attachment_selection_dialog.dart';

final class SizedFile extends PlatformFile {
  SizedFile(this.name, this.size, {this.fail = false});
  @override
  final String name;
  final int? size;
  final bool fail;
  @override
  Uri get uri => Uri.parse('memory:file');
  @override
  get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => size;
  @override
  Future<int?> length() async {
    if (fail) throw StateError('unreadable');
    return size;
  }

  @override
  Future<Uint8List> readAsBytes() => throw UnimplementedError();
  @override
  Stream<Uint8List> readAsByteStream() => throw UnimplementedError();
}

void main() {
  const mb = 1024 * 1024;
  test('파일당 초과 및 크기 확인 실패 파일을 모두 이름으로 안내한다', () async {
    final result = await attachmentSelectionIssue(
      existing: [],
      picked: [
        SizedFile('발표.pdf', 21 * mb),
        SizedFile('오류.zip', null, fail: true),
        SizedFile('정상.txt', 1),
      ],
    );
    expect(result, contains('발표.pdf'));
    expect(result, contains('21.00MB'));
    expect(result, contains('오류.zip'));
    expect(result, contains('크기를 확인할 수 없습니다'));
    expect(result, isNot(contains('정상.txt')));
    expect(result, contains('추가되지 않았습니다'));
  });
  test('개수 초과는 기존·선택 개수와 선택 파일명을 안내한다', () async {
    final existing = List.generate(9, (i) => SizedFile('기존$i.txt', 1));
    final result = await attachmentSelectionIssue(
      existing: existing,
      picked: [SizedFile('첫째.txt', 1), SizedFile('둘째.txt', 1)],
    );
    expect(result, contains('기존 9개 + 선택 2개 = 11개'));
    expect(result, contains('첫째.txt'));
    expect(result, contains('둘째.txt'));
    expect(existing.length, 9);
  });
  test('합계 초과는 기존 파일 포함 실제 합계와 선택 파일 크기를 안내한다', () async {
    final result = await attachmentSelectionIssue(
      existing: [SizedFile('기존1.zip', 20 * mb), SizedFile('기존2.zip', 20 * mb)],
      picked: [SizedFile('추가.zip', 11 * mb)],
    );
    expect(result, contains('51.00MB'));
    expect(result, contains('최대 50MB'));
    expect(result, contains('추가.zip (11.00MB'));
  });
  test('20MB·50MB·10개 경계는 허용하고 1바이트 초과는 설명한다', () async {
    final files = [
      SizedFile('a.zip', 20 * mb),
      SizedFile('b.zip', 20 * mb),
      SizedFile('c.zip', 10 * mb),
      ...List.generate(7, (i) => SizedFile('$i.txt', 0)),
    ];
    expect(await attachmentSelectionIssue(existing: [], picked: files), isNull);
    expect(
      await attachmentSelectionIssue(
        existing: [],
        picked: [SizedFile('초과.zip', 20 * mb + 1)],
      ),
      contains('20971521바이트'),
    );
  });
  testWidgets('좁은 화면의 긴 안내도 스크롤하고 확인으로 닫을 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final issue = List.generate(
      12,
      (i) => '2026학년도_학과_발표자료_아주긴파일이름_$i.pdf\n21MB — 20MB 제한 초과',
    ).join('\n\n');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAttachmentSelectionIssue(context, issue),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('첨부파일을 확인해주세요'), findsNothing);
  });
}
