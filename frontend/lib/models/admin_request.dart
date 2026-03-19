// 💡 관리자 권한 신청 정보를 담는 모델입니다.
class AdminRequest {
  final int id;
  final String requesterName;
  final String loginId;
  final String reason;
  final String status; // PENDING, APPROVED, REJECTED
  final String requestedAt;

  AdminRequest({
    required this.id,
    required this.requesterName,
    required this.loginId,
    required this.reason,
    required this.status,
    required this.requestedAt,
  });

  factory AdminRequest.fromJson(Map<String, dynamic> json) {
    return AdminRequest(
      id: json['id'],
      requesterName: json['requesterName'],
      loginId: json['loginId'],
      reason: json['reason'],
      status: json['status'],
      requestedAt: json['requestedAt'],
    );
  }
}
