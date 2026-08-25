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

  // 💡 작성자 차단
  Future<void> suspendMember(int id) async {
    final dio = ref.read(dioProvider);
    await dio.post('/admin/members/$id/suspend');
  }

  // 💡 작성자 차단 해제
  Future<void> unsuspendMember(int id) async {
    final dio = ref.read(dioProvider);
    await dio.post('/admin/members/$id/unsuspend');
  }

  // 💡 신고 기각 및 대상 복구
  Future<void> dismissReport(String targetType, int targetId) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '/admin/reports/dismiss',
      data: {'targetType': targetType, 'targetId': targetId},
    );
  }
}

final adminProvider = AsyncNotifierProvider<AdminNotifier, List<AdminRequest>>(
  () {
    return AdminNotifier();
  },
);

class AdminReportSummary {
  final String targetType;
  final int targetId;
  final int reportCount;
  final String title;
  final String content;
  final String authorName;
  final int? authorId; // 💡 작성자 차단을 위해 추가
  final bool isAuthorSuspended; // 💡 작성자 차단 여부 추가
  final bool isDeleted;
  final String? deletionReason;
  final List<String> reasons;

  AdminReportSummary({
    required this.targetType,
    required this.targetId,
    required this.reportCount,
    required this.title,
    required this.content,
    required this.authorName,
    this.authorId,
    required this.isAuthorSuspended,
    required this.isDeleted,
    this.deletionReason,
    required this.reasons,
  });

  factory AdminReportSummary.fromJson(Map<String, dynamic> json) {
    return AdminReportSummary(
      targetType: json['targetType'] ?? '',
      targetId: json['targetId'] ?? 0,
      reportCount: json['reportCount'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorName: json['authorName'] ?? '',
      authorId: json['authorId'],
      isAuthorSuspended:
          json['isAuthorSuspended'] ?? json['authorSuspended'] ?? false,
      isDeleted: json['isDeleted'] ?? json['deleted'] ?? false,
      deletionReason: json['deletionReason'],
      reasons: List<String>.from(json['reasons'] ?? []),
    );
  }
}

final adminReportsProvider = FutureProvider<List<AdminReportSummary>>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/reports');
  final list = response.data as List<dynamic>;
  return list.map((json) => AdminReportSummary.fromJson(json)).toList();
});
