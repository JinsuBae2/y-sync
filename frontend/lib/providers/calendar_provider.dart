import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_event.dart';
import 'notice_provider.dart';

// 💡 캘린더 화면에서 현재 선택된 연월(DateTime)을 관리하는 Notifier입니다.
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void updateMonth(DateTime newMonth) {
    state = newMonth;
  }
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(() {
  return SelectedMonthNotifier();
});

// 💡 선택된 월의 시작일과 종료일을 계산하여 학사 일정을 서버에서 가져오는 FutureProvider입니다.
final calendarEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final dio = ref.watch(dioProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  
  // 이전달 20일부터 다음달 10일까지 넓게 패치하여 앞뒤 날짜가 캘린더 뷰에 걸치는 경우에 대비합니다.
  final start = DateTime(selectedMonth.year, selectedMonth.month - 1, 20);
  final end = DateTime(selectedMonth.year, selectedMonth.month + 1, 10);
  
  final startStr = "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
  final endStr = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
  
  final response = await dio.get('/calendar', queryParameters: {
    'startDate': startStr,
    'endDate': endStr,
  });
  
  final List<dynamic> data = response.data as List<dynamic>;
  return data.map((json) => CalendarEvent.fromJson(json)).toList();
});

class CalendarNotifier {
  final Ref ref;
  CalendarNotifier(this.ref);

  Future<void> createEvent(String title, String? description, String startDate, String endDate, String color) async {
    final dio = ref.read(dioProvider);
    await dio.post('/calendar', data: {
      'title': title,
      if (description != null) 'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'color': color,
    });
    ref.invalidate(calendarEventsProvider);
  }

  Future<void> updateEvent(int id, String title, String? description, String startDate, String endDate, String color) async {
    final dio = ref.read(dioProvider);
    await dio.put('/calendar/$id', data: {
      'title': title,
      if (description != null) 'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'color': color,
    });
    ref.invalidate(calendarEventsProvider);
  }

  Future<void> deleteEvent(int id) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/calendar/$id');
    ref.invalidate(calendarEventsProvider);
  }
}

final calendarNotifierProvider = Provider((ref) => CalendarNotifier(ref));
