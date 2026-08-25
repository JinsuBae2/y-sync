import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/timetable_entry.dart';
import 'notice_provider.dart';

// 💡 시간표 조회용 학년 분류 상태 관리 (GRADE_1, GRADE_2, GRADE_3)
class SelectedTimetableGradeNotifier extends Notifier<String> {
  @override
  String build() => 'GRADE_1';

  void updateGrade(String newGrade) {
    state = newGrade;
  }
}

final selectedTimetableGradeProvider =
    NotifierProvider<SelectedTimetableGradeNotifier, String>(() {
      return SelectedTimetableGradeNotifier();
    });

// 💡 선택한 학년의 시간표 데이터를 서버로부터 실시간 페치하는 FutureProvider
final timetableEntriesProvider = FutureProvider<List<TimetableEntry>>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final grade = ref.watch(selectedTimetableGradeProvider);

  final response = await dio.get('/timetable/$grade');
  final List<dynamic> data = response.data as List<dynamic>;
  return data.map((json) => TimetableEntry.fromJson(json)).toList();
});

// 💡 로그인한 학생이 직접 구성한 개인 시간표를 조회합니다.
final personalTimetableEntriesProvider = FutureProvider<List<TimetableEntry>>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/timetable/personal');
  final List<dynamic> data = response.data as List<dynamic>;
  return data.map((json) => TimetableEntry.fromJson(json)).toList();
});

class TimetableNotifier {
  final Ref ref;
  TimetableNotifier(this.ref);

  Future<void> createEntry({
    required String grade,
    required String dayOfWeek,
    required String subjectName,
    required String professorName,
    required String classroom,
    required int startPeriod,
    required int endPeriod,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/timetable',
        data: {
          'grade': grade,
          'dayOfWeek': dayOfWeek,
          'subjectName': subjectName,
          'professorName': professorName,
          'classroom': classroom,
          'startPeriod': startPeriod,
          'endPeriod': endPeriod,
        },
      );
      ref.invalidate(timetableEntriesProvider);
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final message = e.response?.data['message'];
        if (message != null) {
          throw Exception(message);
        }
      }
      rethrow;
    }
  }

  Future<void> updateEntry({
    required int id,
    required String grade,
    required String dayOfWeek,
    required String subjectName,
    required String professorName,
    required String classroom,
    required int startPeriod,
    required int endPeriod,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put(
        '/timetable/$id',
        data: {
          'grade': grade,
          'dayOfWeek': dayOfWeek,
          'subjectName': subjectName,
          'professorName': professorName,
          'classroom': classroom,
          'startPeriod': startPeriod,
          'endPeriod': endPeriod,
        },
      );
      ref.invalidate(timetableEntriesProvider);
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final message = e.response?.data['message'];
        if (message != null) {
          throw Exception(message);
        }
      }
      rethrow;
    }
  }

  Future<void> deleteEntry(int id) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/timetable/$id');
    ref.invalidate(timetableEntriesProvider);
  }

  Future<void> createPersonalEntry({
    required String dayOfWeek,
    required String subjectName,
    required String professorName,
    required String classroom,
    required int startPeriod,
    required int endPeriod,
  }) async {
    await _runPersonalRequest(
      () => ref
          .read(dioProvider)
          .post(
            '/timetable/personal',
            data: {
              'dayOfWeek': dayOfWeek,
              'subjectName': subjectName,
              'professorName': professorName,
              'classroom': classroom,
              'startPeriod': startPeriod,
              'endPeriod': endPeriod,
            },
          ),
    );
  }

  Future<void> updatePersonalEntry({
    required int id,
    required String dayOfWeek,
    required String subjectName,
    required String professorName,
    required String classroom,
    required int startPeriod,
    required int endPeriod,
  }) async {
    await _runPersonalRequest(
      () => ref
          .read(dioProvider)
          .put(
            '/timetable/personal/$id',
            data: {
              'dayOfWeek': dayOfWeek,
              'subjectName': subjectName,
              'professorName': professorName,
              'classroom': classroom,
              'startPeriod': startPeriod,
              'endPeriod': endPeriod,
            },
          ),
    );
  }

  Future<void> deletePersonalEntry(int id) async {
    await _runPersonalRequest(
      () => ref.read(dioProvider).delete('/timetable/personal/$id'),
    );
  }

  Future<void> _runPersonalRequest(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      await request();
      ref.invalidate(personalTimetableEntriesProvider);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['message'] is String) {
        throw Exception(data['message']);
      }
      rethrow;
    }
  }
}

final timetableNotifierProvider = Provider((ref) => TimetableNotifier(ref));
