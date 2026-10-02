import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/models/notice_grade_preference.dart';
import 'package:y_sync/models/notice_grade_stats.dart';
import 'package:y_sync/providers/api_client_provider.dart';
import 'package:y_sync/providers/auth_provider.dart';
import 'package:y_sync/providers/notice_grade_prompt_provider.dart';
import 'package:y_sync/widgets/notice_grade_prompt.dart';

Member member({
  String? preference,
  int? confirmedYear,
  int? currentYear = 2027,
  bool confirmationRequired = false,
}) {
  return Member.fromJson({
    'id': 1,
    'loginId': '2305001',
    'name': '학생',
    'role': 'USER',
    'noticeEnabled': true,
    'commentEnabled': true,
    'activated': true,
    'noticeGradePreference': preference,
    'gradeConfirmedYear': confirmedYear,
    'currentAcademicYear': currentYear,
    'gradeConfirmationRequired': confirmationRequired,
  });
}

void main() {
  _statsTests();

  group('선택값 해석', () {
    test('미설정은 null이며 전체 공지만 받기와 구분된다', () {
      expect(member(preference: null).noticeGradePreference, isNull);
      expect(
        member(preference: 'GENERAL_ONLY').noticeGradePreference,
        NoticeGradePreference.generalOnly,
      );
      expect(NoticeGradePreference.labelOf(null), '미설정');
      expect(
        NoticeGradePreference.labelOf(NoticeGradePreference.generalOnly),
        '전체 공지만 받기',
      );
    });

    test('네 가지 선택지를 모두 해석한다', () {
      expect(NoticeGradePreference.values.map((e) => e.wireValue).toList(), [
        'GRADE_1',
        'GRADE_2',
        'GRADE_3',
        'GENERAL_ONLY',
      ]);
      for (final preference in NoticeGradePreference.values) {
        expect(
          NoticeGradePreference.fromWire(preference.wireValue),
          preference,
        );
      }
    });

    test('관리자 응답의 인증 메일을 읽고 본인 응답에는 없어도 된다', () {
      // 학교 메일은 학번에서 유도할 수 없어 도용을 예방할 수 없습니다. 관리자가 신고를 받았을 때
      // 가해자를 특정할 수 있도록 회원 관리 응답에서만 메일을 내려줍니다.
      final adminRow = Member.fromJson({
        'id': 1,
        'loginId': '2305001',
        'name': '학생',
        'role': 'USER',
        'activated': true,
        'noticeEnabled': true,
        'commentEnabled': true,
        'email': 'hong@ync.ac.kr',
      });
      expect(adminRow.email, 'hong@ync.ac.kr');

      // 본인 조회 응답에는 email이 없으며 그 경우 null이어야 합니다.
      expect(member().email, isNull);
    });

    test('모르는 값이나 필드 누락에도 앱이 깨지지 않는다', () {
      expect(NoticeGradePreference.fromWire('GRADE_4'), isNull);
      final legacy = Member.fromJson({
        'id': 1,
        'loginId': '2305001',
        'name': '학생',
        'role': 'USER',
        'noticeEnabled': true,
        'commentEnabled': true,
        'activated': true,
      });
      expect(legacy.noticeGradePreference, isNull);
      expect(legacy.gradeConfirmedYear, isNull);
      expect(legacy.currentAcademicYear, isNull);
      expect(legacy.gradeConfirmationRequired, isFalse);
    });
  });

  group('안내 반복 방지', () {
    test('같은 학년도에는 한 번만 안내하고 학년도가 바뀌면 다시 안내한다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(noticeGradePromptProvider.notifier);

      expect(notifier.shouldPrompt(2027), isTrue);
      notifier.markPrompted(2027);
      expect(notifier.shouldPrompt(2027), isFalse);
      expect(notifier.shouldPrompt(2028), isTrue);
    });
  });

  group('안내 표시 조건', () {
    Future<void> pumpPrompt(WidgetTester tester, Member current) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _StubAuthNotifier(current)),
          ],
          child: const MaterialApp(
            home: NoticeGradePrompt(child: Scaffold(body: Text('홈'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('확인이 필요하면 첫 설정 안내가 뜬다', (tester) async {
      await pumpPrompt(tester, member(confirmationRequired: true));

      expect(find.text('공지 알림을 받을 학년을 선택해 주세요.'), findsOneWidget);
      expect(find.text('1학년'), findsOneWidget);
      expect(find.text('전체 공지만 받기'), findsOneWidget);
      expect(find.text('나중에'), findsOneWidget);
    });

    testWidgets('이전 선택이 있으면 재확인 안내와 이전 값을 보여준다', (tester) async {
      await pumpPrompt(
        tester,
        member(
          preference: 'GRADE_1',
          confirmedYear: 2026,
          confirmationRequired: true,
        ),
      );

      expect(find.text('올해 현재 학년을 확인해 주세요.'), findsOneWidget);
      expect(find.text('이전 선택: 1학년'), findsOneWidget);
    });

    testWidgets('확인이 끝난 회원에게는 안내하지 않는다', (tester) async {
      await pumpPrompt(
        tester,
        member(preference: 'GRADE_2', confirmedYear: 2027),
      );

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('서버가 학년도를 주지 않으면 단말기 날짜로 추측하지 않는다', (tester) async {
      await pumpPrompt(
        tester,
        member(currentYear: null, confirmationRequired: true),
      );

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('나중에를 고르면 앱 사용을 막지 않고 같은 세션에서 다시 뜨지 않는다', (tester) async {
      await pumpPrompt(tester, member(confirmationRequired: true));

      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('홈'), findsOneWidget);

      // 화면이 다시 그려져도 같은 학년도에는 안내가 반복되지 않아야 한다.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('저장 동작', () {
    testWidgets('저장 실패 시 기존 선택을 유지하고 재시도를 안내한다', (tester) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _FailingAdapter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            authProvider.overrideWith(
              () => _StubAuthNotifier(
                member(
                  preference: 'GRADE_1',
                  confirmedYear: 2026,
                  confirmationRequired: true,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: NoticeGradePrompt(child: Scaffold(body: Text('홈'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('2학년'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(find.text('저장하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.'), findsOneWidget);
      // 대화상자가 닫히지 않아 사용자가 곧바로 재시도할 수 있어야 한다.
      expect(find.text('올해 현재 학년을 확인해 주세요.'), findsOneWidget);
      expect(find.text('이전 선택: 1학년'), findsOneWidget);
    });

    testWidgets('선택 전에는 저장할 수 없다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _StubAuthNotifier(member(confirmationRequired: true)),
            ),
          ],
          child: const MaterialApp(
            home: NoticeGradePrompt(child: Scaffold(body: Text('홈'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '저장'),
      );
      expect(saveButton.onPressed, isNull);
    });
  });
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(this._member);

  final Member? _member;

  @override
  Future<Member?> build() async => _member;
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: '네트워크 연결 없음',
    );
  }
}

/// 💡 전환 판단용 집계 파싱을 고정합니다. 미설정 인원이 곧 전환 시 영향받는 인원입니다.
void _statsTests() {
  group('전환 현황 집계', () {
    test('선택값별 인원과 미설정 인원, 비율을 읽는다', () {
      final stats = NoticeGradeStats.fromJson({
        'currentAcademicYear': 2027,
        'noticeTargetCount': 300,
        'unsetCount': 120,
        'selectedCount': 180,
        'needsConfirmationCount': 150,
        'countsByPreference': {
          'GRADE_1': 60,
          'GRADE_2': 70,
          'GRADE_3': 30,
          'GENERAL_ONLY': 20,
        },
      });

      expect(stats.unsetCount, 120);
      expect(stats.selectedPercent, 60);
      expect(stats.countsByPreference[NoticeGradePreference.grade1], 60);
      expect(stats.countsByPreference[NoticeGradePreference.generalOnly], 20);
    });

    test('빠진 선택지는 0으로 채우고 대상이 없으면 비율은 0이다', () {
      final stats = NoticeGradeStats.fromJson({
        'currentAcademicYear': 2027,
        'noticeTargetCount': 0,
        'unsetCount': 0,
        'selectedCount': 0,
        'needsConfirmationCount': 0,
        'countsByPreference': <String, dynamic>{},
      });

      expect(stats.selectedPercent, 0);
      expect(
        stats.countsByPreference.length,
        NoticeGradePreference.values.length,
      );
      expect(stats.countsByPreference.values, everyElement(0));
    });
  });
}
