import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/providers/notice_provider.dart';
import 'package:y_sync/providers/notification_provider.dart';
import 'package:y_sync/providers/scrap_provider.dart';
import 'package:y_sync/providers/session_provider.dart';
import 'package:y_sync/providers/timetable_provider.dart';

void main() {
  test('계정 전환 시 개인 캐시만 비우고 새 계정 데이터를 조회한다', () async {
    final calls = <String, int>{};
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.update(options.path, (count) => count + 1, ifAbsent: () => 1);
          final data = switch (options.path) {
            '/timetable/personal' => [
              {
                'id': calls[options.path],
                'grade': 'PERSONAL',
                'dayOfWeek': 'MONDAY',
                'subjectName': '계정 ${calls[options.path]} 수업',
                'professorName': '',
                'classroom': '',
                'startPeriod': 1,
                'endPeriod': 1,
              },
            ],
            '/timetable/GRADE_1' => <Map<String, dynamic>>[],
            _ => <Map<String, dynamic>>[],
          };
          handler.resolve(
            Response<dynamic>(requestOptions: options, data: data),
          );
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    container.read(sessionMemberIdProvider.notifier).activate(13);
    final first = await container.read(personalTimetableEntriesProvider.future);
    await container.read(notificationsProvider.future);
    await container.read(scrapsProvider.future);
    await container.read(timetableEntriesProvider.future);
    expect(first.single.subjectName, '계정 1 수업');

    container.read(sessionMemberIdProvider.notifier).clear();
    expect(
      await container.read(personalTimetableEntriesProvider.future),
      isEmpty,
    );
    expect(await container.read(notificationsProvider.future), isEmpty);
    expect(await container.read(scrapsProvider.future), isEmpty);

    container.read(sessionMemberIdProvider.notifier).activate(1);
    final second = await container.read(
      personalTimetableEntriesProvider.future,
    );
    await container.read(notificationsProvider.future);
    await container.read(scrapsProvider.future);
    await container.read(timetableEntriesProvider.future);

    expect(second.single.subjectName, '계정 2 수업');
    expect(calls['/timetable/personal'], 2);
    expect(calls['/notifications'], 2);
    expect(calls['/scraps'], 2);
    expect(calls['/timetable/GRADE_1'], 1);
  });
}
