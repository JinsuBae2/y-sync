import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scrap.dart';
import 'notice_provider.dart';

// 💡 내 스크랩 목록을 서버에서 가져옵니다.
final scrapsProvider = FutureProvider<List<Scrap>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/scraps');
  final List<dynamic> data = response.data;
  return data.map((json) => Scrap.fromJson(json)).toList();
});

class ScrapNotifier {
  final Ref ref;

  ScrapNotifier(this.ref);

  // 💡 특정 게시글의 스크랩 여부를 토글합니다.
  Future<void> toggleScrap(String targetType, int targetId) async {
    final dio = ref.read(dioProvider);
    try {
      await dio.post('/scraps', queryParameters: {
        'targetType': targetType,
        'targetId': targetId,
      });
      // 성공하면 즉시 스크랩 목록 캐시를 무효화하여 모든 UI의 🔖 기호가 갱신되도록 합니다.
      ref.invalidate(scrapsProvider);
    } catch (e) {
      // 에러 처리 (필요 시)
      print('Scrap toggle error: $e');
    }
  }
}

final scrapNotifierProvider = Provider((ref) => ScrapNotifier(ref));
