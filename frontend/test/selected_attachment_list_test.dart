import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/widgets/selected_attachment_list.dart';

final class SampleFile extends PlatformFile {
  SampleFile(this.name, this.bytes);
  @override
  final String name;
  final Uint8List bytes;
  @override
  Uri get uri => Uri.parse('memory:$name');
  @override
  get xFile => throw UnimplementedError();
  @override
  int lengthSync() => bytes.length;
  @override
  Future<int> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

final red = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAeUlEQVR4nO3PQQkAMAzAwCqpf1ETMxF7HINABFzm7H7dcEEDWtCAFjSgBQ1oQQNa0IAWNKAFDWhBA1rQgBY0oAUNaEEDWtCAFjSgBQ1oQQNa0IAWNKAFDWhBA1rQgBY0oAUNaEEDWtCAFjSgBQ1oQQNa0IAWNKAFj13PLIEAOXyUUwAAAABJRU5ErkJggg==',
);
final blue = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAeklEQVR4nO3PUQkAIBTAwJfETPbHMIbw4xAGC3Cbtc/XDRc0oAUNaEEDWtCAFjSgBQ1oQQNa0IAWNKAFDWhBA1rQgBY0oAUNaEEDWtCAFjSgBQ1oQQNa0IAWNKAFDWhBA1rQgBY0oAUNaEEDWtCAFjSgBQ1oQQNa8NgFeOuhLQyNEQUAAAAASUVORK5CYII=',
);

void main() {
  testWidgets('앞 이미지를 삭제해도 남은 파일 이름과 미리보기가 일치한다', (tester) async {
    final files = <PlatformFile>[
      SampleFile('red.png', red),
      SampleFile('blue.png', blue),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SelectedAttachmentList(
              files: files,
              onRemove: (index) => setState(() => files.removeAt(index)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('첨부 삭제').first);
    await tester.pumpAndSettle();
    expect(find.text('blue.png'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as MemoryImage).bytes, blue);
  });
  testWidgets('잘린 파일명을 눌러 전체 이름과 이미지 확인 후 닫을 수 있다', (tester) async {
    const name = '2026학년도_2학기_팀프로젝트_최종발표_제출안내_수정본.png';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SelectedAttachmentList(
              files: [SampleFile(name, blue)],
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    expect(find.text('첨부파일 확인'), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      name,
    );
    expect(tester.widget<Image>(find.byType(Image).last).fit, BoxFit.contain);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('첨부파일 확인'), findsNothing);
  });
  testWidgets('손상된 이미지도 첨부 삭제가 가능하다', (tester) async {
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectedAttachmentList(
            files: [SampleFile('broken.png', Uint8List(3))],
            onRemove: (_) => removed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('첨부 삭제'));
    expect(removed, isTrue);
  });
}
