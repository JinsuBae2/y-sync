import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/providers/notice_provider.dart';
import 'package:y_sync/providers/session_provider.dart';
import 'package:y_sync/screens/help_screen.dart';
import 'package:y_sync/screens/feedback_screen.dart';
import 'package:y_sync/screens/admin_feedback_screen.dart';

void main() {
  testWidgets('320px 도움말에서 답변을 펼치고 의견 작성으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HelpScreen())),
    );
    expect(find.text('💡'), findsOneWidget);
    expect(find.text('자주 묻는 질문'), findsOneWidget);
    expect(find.text('Q1'), findsWidgets);
    await tester.tap(find.text('학과 시간표와 개인 시간표는 어떻게 다른가요?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('나만의 시간표입니다.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('오류 신고·개선 제안 보내기'), 300);
    await tester.tap(find.text('오류 신고·개선 제안 보내기'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('실패한 의견은 입력을 유지하고 재전송 성공 뒤 완료 안내를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio();
    var attempts = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          attempts++;
          final form = options.data as FormData;
          expect(form.fields.toMap()['title'], '시간표 오류');
          if (attempts == 1) {
            handler.reject(DioException(requestOptions: options));
          } else {
            handler.resolve(Response(requestOptions: options, statusCode: 201));
          }
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
    container.read(sessionMemberIdProvider.notifier).activate(1);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FeedbackScreen()),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('오류 신고'), findsOneWidget);
    expect(find.text('개선 제안'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '시간표 오류');
    await tester.enterText(find.byType(TextFormField).at(1), '오류 재현 내용');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, '의견 보내기');
    await tester.scrollUntilVisible(
      submit,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(submit), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(attempts, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('의견을 보내주셔서 감사합니다.'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('관리자는 제보를 펼쳐 확인 처리하고 미확인 목록에서 제거한다', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio();
    var reviewed = false;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'PUT') reviewed = true;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'content': reviewed
                    ? []
                    : [
                        {
                          'id': 1,
                          'category': 'BUG',
                          'title': '시간표 제보',
                          'content': '재현 단계',
                          'screen': '시간표',
                          'clientInfo': 'Web/PWA',
                          'createdAt': '2026-09-09T10:00:00',
                          'reviewed': false,
                          'imageIds': [],
                        },
                      ],
                'last': true,
              },
            ),
          );
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
    container.read(sessionMemberIdProvider.notifier).activate(1);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AdminFeedbackScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('사용자 의견함'), findsOneWidget);
    expect(find.text('미확인'), findsWidgets);
    await tester.tap(find.text('시간표 제보'));
    await tester.pumpAndSettle();
    final reviewButton = find.byKey(const ValueKey('admin-feedback-review-1'));
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();
    expect(reviewed, isTrue);
    expect(find.text('등록된 의견이 없습니다.'), findsOneWidget);
  });
}

extension on List<MapEntry<String, String>> {
  Map<String, String> toMap() => Map.fromEntries(this);
}
