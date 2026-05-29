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

final selectedTimetableGradeProvider = NotifierProvider<SelectedTimetableGradeNotifier, String>(() {
  return SelectedTimetableGradeNotifier();
});

// 💡 선택한 학년의 시간표 데이터를 서버로부터 실시간 페치하는 FutureProvider
final timetableEntriesProvider = FutureProvider<List<TimetableEntry>>((ref) async {
  final dio = ref.watch(dioProvider);
  final grade = ref.watch(selectedTimetableGradeProvider);
  
  final response = await dio.get('/timetable/$grade');
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
      await dio.post('/timetable', data: {
        'grade': grade,
        'dayOfWeek': dayOfWeek,
        'subjectName': subjectName,
        'professorName': professorName,
        'classroom': classroom,
        'startPeriod': startPeriod,
        'endPeriod': endPeriod,
      });
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
      await dio.put('/timetable/$id', data: {
        'grade': grade,
        'dayOfWeek': dayOfWeek,
        'subjectName': subjectName,
        'professorName': professorName,
        'classroom': classroom,
        'startPeriod': startPeriod,
        'endPeriod': endPeriod,
      });
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
}

final timetableNotifierProvider = Provider((ref) => TimetableNotifier(ref));
