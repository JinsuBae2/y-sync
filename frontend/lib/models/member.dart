class Member {
  final int id;
  final String loginId;
  final String name;
  final String role;
  final bool noticeEnabled;
  final bool commentEnabled;
  final bool isActivated; // 💡 가입(활성화) 여부 추가

  Member({
    required this.id,
    required this.loginId,
    required this.name,
    required this.role,
    required this.noticeEnabled,
    required this.commentEnabled,
    required this.isActivated,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? 0,
      loginId: json['loginId'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      noticeEnabled: json['noticeEnabled'] ?? true,
      commentEnabled: json['commentEnabled'] ?? true,
      isActivated: json['activated'] ?? json['isActivated'] ?? false,
    );
  }
}
