import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calendar_event.dart';
import '../models/community_post.dart';
import '../models/notice.dart';
import 'notice_provider.dart';

final homeNoticesProvider = FutureProvider<List<Notice>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/notices',
    queryParameters: const {'page': 0, 'size': 20},
  );

  final responseData = response.data;
  final List<dynamic> items;
  if (responseData is Map<String, dynamic>) {
    items = responseData['content'] as List<dynamic>? ?? const [];
  } else if (responseData is List<dynamic>) {
    items = responseData;
  } else {
    items = const [];
  }

  return items
      .map((item) => Notice.fromJson(item as Map<String, dynamic>))
      .toList();
});

final homeCommunityPostsProvider = FutureProvider<List<CommunityPost>>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/community');
  final items = response.data as List<dynamic>? ?? const [];

  return items
      .map((item) => CommunityPost.fromJson(item as Map<String, dynamic>))
      .where((post) => !post.isDeleted)
      .toList();
});

final homeCalendarEventsProvider = FutureProvider<List<CalendarEvent>>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final today = DateTime.now();
  final end = today.add(const Duration(days: 60));
  final response = await dio.get(
    '/calendar',
    queryParameters: {
      'startDate': _formatApiDate(today),
      'endDate': _formatApiDate(end),
    },
  );
  final items = response.data as List<dynamic>? ?? const [];

  final events = items
      .map((item) => CalendarEvent.fromJson(item as Map<String, dynamic>))
      .toList();
  events.sort((a, b) => a.startDate.compareTo(b.startDate));
  return events;
});

String _formatApiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
