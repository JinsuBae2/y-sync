import 'dart:async';

import 'package:y_sync/widgets/unsaved_form_guard.dart';

import 'package:dio/dio.dart';
import 'package:y_sync/providers/api_client_provider.dart';
import 'package:y_sync/models/notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/screens/community_form_screen.dart';
import 'package:y_sync/screens/notice_form_screen.dart';
import 'package:y_sync/screens/feedback_screen.dart';

void main() {
  testWidgets('320px·글자 2배에서도 확인창 버튼에 접근할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '작성 중');
    addTearDown(controller.dispose);
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
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => UnsavedFormGuard(
                    controllers: [controller],
                    hasChanges: () => true,
                    child: Scaffold(appBar: AppBar(title: const Text('작성'))),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('계속 작성'));
    await tester.tap(find.text('계속 작성'));
    await tester.pumpAndSettle();
    expect(controller.text, '작성 중');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('변경 내용 버리기'));
    await tester.tap(find.text('변경 내용 버리기'));
    await tester.pumpAndSettle();
    expect(find.text('열기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기존 행사 공지는 변경하지 않으면 바로 닫힌다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('열기'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NoticeFormScreen(
                      notice: Notice(
                        id: 1,
                        title: '행사',
                        content: '내용',
                        authorName: '관리자',
                        noticeType: 'NEWS',
                        createdAt: '2026-10-28',
                        eventStartDate: '2026-11-01',
                        eventEndDate: '2026-11-03',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('열기'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('게시글 저장 중 이탈 차단, 성공하면 확인 없이 결과 반환', (tester) async {
    final pending = Completer<void>();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await pending.future;
          handler.resolve(Response(requestOptions: options, statusCode: 201));
        },
      ),
    );
    addTearDown(dio.close);
    Object? saved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('열기'),
                onPressed: () async {
                  saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) => const CommunityFormScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '제목');
    await tester.enterText(find.byType(TextField).at(1), '내용');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('게시글 등록'));
    await tester.tap(find.text('게시글 등록'));
    await tester.pump();
    await tester.pageBack();
    await tester.pump();
    expect(find.byType(CommunityFormScreen), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(saved, true);
    expect(find.text('열기'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  for (final entry in <String, Widget>{
    '게시글': const CommunityFormScreen(),
    '공지': const NoticeFormScreen(),
    '의견': const FeedbackScreen(),
  }.entries) {
    testWidgets('${entry.key}: 변경 확인, 계속 작성, 폐기', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => entry.value)),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '작성 중인 제목');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('작성을 그만할까요?'), findsOneWidget);
      await tester.tap(find.text('계속 작성'));
      await tester.pumpAndSettle();
      expect(find.text('작성 중인 제목'), findsOneWidget);
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('변경 내용 버리기'));
      await tester.pumpAndSettle();
      expect(find.text('열기'), findsOneWidget);
    });
    testWidgets('${entry.key}: 원래 값으로 되돌리면 확인 없이 나간다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => entry.value)),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '임시');
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('작성을 그만할까요?'), findsNothing);
      expect(find.text('열기'), findsOneWidget);
    });
  }
}
