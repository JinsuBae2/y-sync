import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/platform_file_multipart.dart';
import 'notice_provider.dart';
import 'session_provider.dart';

const feedbackCategories = {
  'BUG': '오류 신고',
  'SUGGESTION': '개선 제안',
  'OTHER': '기타 의견',
};

// 💡 관리자 목록도 계정 변경 시 폐기하며 공개 Provider와 분리합니다.
final adminFeedbackProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({bool? reviewed, int page})>((
      ref,
      filter,
    ) async {
      if (ref.watch(sessionMemberIdProvider) == null) {
        return {'content': <dynamic>[], 'last': true};
      }
      final response = await ref
          .watch(dioProvider)
          .get(
            '/admin/feedback',
            queryParameters: {
              'page': filter.page,
              if (filter.reviewed != null) 'reviewed': filter.reviewed,
            },
          );
      return Map<String, dynamic>.from(response.data as Map);
    });

final feedbackServiceProvider = Provider((ref) => FeedbackService(ref));

class FeedbackService {
  FeedbackService(this.ref);
  final Ref ref;

  Future<void> submit({
    required String category,
    required String title,
    required String content,
    required String screen,
    required List<PlatformFile> images,
  }) async {
    final memberId = ref.read(sessionMemberIdProvider);
    if (memberId == null) throw StateError('로그인이 필요합니다.');
    final form = FormData.fromMap({
      'category': category,
      'title': title.trim(),
      'content': content.trim(),
      'screen': screen.trim(),
      'clientInfo':
          'Y-Sync 1.0.0 · ${kIsWeb ? "Web/PWA" : "App"} · ${defaultTargetPlatform.name}',
    });
    for (final image in images) {
      form.files.add(MapEntry('images', await platformFileToMultipart(image)));
    }
    if (ref.read(sessionMemberIdProvider) != memberId) {
      throw StateError('계정이 변경되었습니다. 다시 작성해주세요.');
    }
    await ref.read(dioProvider).post('/feedback', data: form);
  }
}
