import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/providers/session_provider.dart';
import 'package:y_sync/screens/community_form_screen.dart';
import 'package:y_sync/screens/notice_form_screen.dart';
import 'package:y_sync/services/writing_draft.dart';

class MemoryDraftStore extends DraftStore {
  final values = <String, String>{};
  bool fail = false;
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) {
    if (fail) throw StateError('quota');
    values[key] = value;
  }

  @override
  void remove(String key) {
    if (fail) throw StateError('denied');
    values.remove(key);
  }
}

void main() {
  test('새 인스턴스 복원, 계정·종류·수정 대상 분리, 게시 완료 후 삭제', () {
    final store = MemoryDraftStore();
    final draft = WritingDraft(store, memberId: 1, kind: 'notice');
    draft.save({'title': '초안', 'content': '내용'}, hasChanges: true);
    expect(
      WritingDraft(store, memberId: 1, kind: 'notice').restore()?['title'],
      '초안',
    );
    expect(WritingDraft(store, memberId: 2, kind: 'notice').restore(), isNull);
    expect(
      WritingDraft(store, memberId: 1, kind: 'community').restore(),
      isNull,
    );
    expect(
      WritingDraft(store, memberId: 1, kind: 'notice', postId: 3).restore(),
      isNull,
    );
    expect(draft.complete(), isTrue);
    draft.save({'title': '남은 콜백', 'content': ''}, hasChanges: true);
    expect(store.values, isEmpty);
  });
  test('저장 실패는 저장 성공으로 표시하지 않으며 삭제 실패는 이탈을 막는다', () {
    final store = MemoryDraftStore()..fail = true;
    final draft = WritingDraft(store, memberId: 1, kind: 'notice');
    draft.save({'title': '초안', 'content': ''}, hasChanges: true);
    expect(draft.value, contains('저장하지 못했습니다'));
    expect(draft.discard(), isFalse);
    store.fail = false;
    draft.save({'title': '초안', 'content': ''}, hasChanges: true);
    expect(store.values, isNotEmpty);
    expect(draft.discard(), isTrue);
    expect(store.values, isEmpty);
  });
  test('손상된 저장 데이터는 작성 화면을 막지 않는다', () {
    final store = MemoryDraftStore();
    final draft = WritingDraft(store, memberId: 1, kind: 'notice');
    store.values[draft.key] = '{broken';
    expect(draft.restore(), isNull);
    expect(draft.value, contains('읽지 못했습니다'));
  });

  for (final notice in [true, false]) {
    testWidgets('${notice ? '공지' : '커뮤니티'} 화면 재생성 시 입력 복원 및 명시적 버리기', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryDraftStore();
      final container = ProviderContainer(
        overrides: [draftStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      container.read(sessionMemberIdProvider.notifier).activate(1);
      Widget app() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('열기'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => notice
                        ? const NoticeFormScreen()
                        : const CommunityFormScreen(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '복원할 제목');
      await tester.enterText(find.byType(TextField).at(1), '복원할 본문');
      await tester.tap(find.text(notice ? '중요' : 'Q&A'));
      await tester.tap(find.text('2학년'));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(store.values.length, 1);
      final saved = jsonDecode(store.values.values.single) as Map;
      expect(saved['targetGrade'], 'GRADE_2');
      expect(
        saved[notice ? 'noticeType' : 'category'],
        notice ? 'NOTICE' : 'QA',
      );
      expect(saved[notice ? 'isEvent' : 'anonymous'], true);
      // Dispose without in-app discard, as a browser reload would do.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].controller!.text, '복원할 제목');
      expect(fields[1].controller!.text, '복원할 본문');
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
      expect(find.textContaining('초안을 복원했습니다'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('변경 내용 버리기'));
      await tester.pumpAndSettle();
      expect(store.values, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
