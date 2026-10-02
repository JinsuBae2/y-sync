import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/widgets/content_filter_bar.dart';

void main() {
  testWidgets('필터의 선택 상태를 화면 읽기에도 전달한다', (tester) async {
    final semantics = tester.ensureSemantics();
    var selection = 'ALL';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ContentFilterBar(
                label: '학년',
                icon: Icons.school_outlined,
                options: const [('ALL', '전체'), ('GRADE_1', '1학년')],
                selectedValue: selection,
                isGlass: true,
                onChanged: (value) => setState(() => selection = value),
              );
            },
          ),
        ),
      ),
    );
    expect(
      tester
          .getSemantics(find.text('전체'))
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      isTrue,
    );
    await tester.tap(find.text('1학년'));
    await tester.pump();
    expect(selection, 'GRADE_1');
    expect(
      tester
          .getSemantics(find.text('1학년'))
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.text('전체'))
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      isFalse,
    );
    semantics.dispose();
  });
}
