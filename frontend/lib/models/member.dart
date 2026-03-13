class Member {
  final String loginId;
  final String name;
  final String role;

  Member({
    required this.loginId,
    required this.name,
    required this.role,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      loginId: json['loginId'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
    );
  }
}
