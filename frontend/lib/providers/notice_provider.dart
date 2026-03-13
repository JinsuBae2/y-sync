import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/notice.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    // Android Emulator: 10.0.2.2, iOS/Web: localhost
    baseUrl: 'http://localhost:8080/api/v1',
    // Enable sending cookies (JSESSIONID) for cross-origin requests on Web
    extra: {'withCredentials': true},
  ));
});

final noticesProvider = FutureProvider<List<Notice>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/notices');
  
  final List<dynamic> data = response.data;
  return data.map((json) => Notice.fromJson(json)).toList();
});

class NoticeNotifier {
  final Ref ref;

  NoticeNotifier(this.ref);

  Future<void> createNotice(String title, String content, String author) async {
    final dio = ref.read(dioProvider);
    await dio.post('/admin/notices', data: {
      'title': title,
      'content': content,
      'author': author,
    });
    
    // Refresh the notices list
    ref.invalidate(noticesProvider);
  }
}

final noticeNotifierProvider = Provider((ref) => NoticeNotifier(ref));
