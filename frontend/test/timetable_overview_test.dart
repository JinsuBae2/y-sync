import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/models/member.dart';
import 'package:y_sync/models/timetable_entry.dart';
import 'package:y_sync/providers/auth_provider.dart';
import 'package:y_sync/providers/timetable_provider.dart';
import 'package:y_sync/screens/timetable_view.dart';

class _StudentAuth extends AuthNotifier {
  @override
  Future<Member?> build() async => Member(
    id: 1,
    loginId: 'test-student',
    name: '학생',
    role: 'USER',
    noticeEnabled: true,
    commentEnabled: true,
    isActivated: true,
  );
}

class _AdminAuth extends _StudentAuth {
  @override
  Future<Member?> build() async => Member(
    id: 1,
    loginId: 'test-admin',
    name: '관리자',
    role: 'ADMIN',
    noticeEnabled: true,
    commentEnabled: true,
    isActivated: true,
  );
}

TimetableEntry course(int id, String day, int start, int end) => TimetableEntry(
  id: id,
  grade: 'GRADE_1',
  dayOfWeek: day,
  subjectName: '모바일 프로그래밍 $id',
  professorName: '김교수',
  classroom: '301호',
  startPeriod: start,
  endPeriod: end,
);

void main() {
  for (final width in [320.0, 390.0, 768.0, 321.0]) {
    testWidgets('${width.toInt()}px 주간 시간표의 모든 요일과 수업이 화면 안에 있다', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_StudentAuth.new),
            timetableEntriesProvider.overrideWith(
              (ref) async => [
                course(1, 'MONDAY', 1, 2),
                course(2, 'FRIDAY', 3, 3),
                if (width != 390) course(3, 'SATURDAY', 1, 1),
                course(4, 'MONDAY', 2, 2),
              ],
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 321 ? 2 : 1)),
              child: child!,
            ),
            home: const TimetableView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('토'), width == 390 ? findsNothing : findsOneWidget);
      final first = tester.getRect(
        find.byKey(const ValueKey('weekly-course-1')),
      );
      final overlapping = tester.getRect(
        find.byKey(const ValueKey('weekly-course-4')),
      );
      expect(first.overlaps(overlapping), isFalse);
      for (final id in [1, 2, if (width != 390) 3, 4]) {
        final card = find.byKey(ValueKey('weekly-course-$id'));
        expect(card, findsOneWidget);
        final rect = tester.getRect(card);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
      await tester.tap(find.byKey(const ValueKey('weekly-course-1')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('course-details'))).width,
        width > 640 ? 640 : width,
      );
      expect(find.text('김교수 교수'), findsOneWidget);
      expect(find.text('09:00 - 11:00'), findsOneWidget);
      expect(find.text('수정'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final personal in [false, true]) {
    testWidgets(
      personal ? '학생은 개인 수업 상세에서 수정에 진입한다' : '관리자는 학과 수업 상세에서 수정에 진입한다',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                personal ? _StudentAuth.new : _AdminAuth.new,
              ),
              timetableEntriesProvider.overrideWith(
                (ref) async => [course(1, 'MONDAY', 1, 2)],
              ),
              personalTimetableEntriesProvider.overrideWith(
                (ref) async => [course(2, 'TUESDAY', 2, 3)],
              ),
            ],
            child: const MaterialApp(home: TimetableView()),
          ),
        );
        await tester.pumpAndSettle();
        if (personal) {
          await tester.tap(find.text('개인 시간표'));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.byKey(ValueKey('weekly-course-${personal ? 2 : 1}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('수정'));
        await tester.pumpAndSettle();
        expect(find.text(personal ? '내 수업 수정' : '학과 수업 수정'), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
