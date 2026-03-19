import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_request.dart';
import 'notice_provider.dart';

// 💡 관리자 신청 및 승인 프로세스를 관리하는 Provider입니다.
class AdminNotifier extends AsyncNotifier<List<AdminRequest>> {
  @override
  Future<List<AdminRequest>> build() async {
    // 💡 초기 상태는 빈 목록 (SUPER_ADMIN이 접근할 때만 데이터를 채웁니다.)
    return [];
  }

  // 💡 승인 대기 목록 가져오기 (SUPER_ADMIN 전용)
  Future<void> fetchPendingRequests() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/admin/requests');
      final list = response.data as List<dynamic>;
      return list.map((json) => AdminRequest.fromJson(json)).toList();
    });
  }

  // 💡 관리자 권한 신청 제출
  Future<void> submitRequest(String reason) async {
    final dio = ref.read(dioProvider);
    await dio.post('/admin/requests', data: {'reason': reason});
  }

  // 💡 신청 승인
  Future<void> approveRequest(int id) async {
    final dio = ref.read(dioProvider);
    await dio.post('/admin/requests/$id/approve');
    await fetchPendingRequests(); // 목록 갱신
  }

  // 💡 신청 거절
  Future<void> rejectRequest(int id) async {
    final dio = ref.read(dioProvider);
    await dio.post('/admin/requests/$id/reject');
    await fetchPendingRequests(); // 목록 갱신
  }
}

final adminProvider = AsyncNotifierProvider<AdminNotifier, List<AdminRequest>>(() {
  return AdminNotifier();
});
