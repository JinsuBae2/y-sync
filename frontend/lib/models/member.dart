class Member {
  final int id;
  final String loginId;
  final String name;
  final String role;

  Member({
    required this.id,
    required this.loginId,
    required this.name,
    required this.role,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? 0,
      loginId: json['loginId'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
    );
  }
}
