class Comment {
  final int id;
  final String content;
  final int? noticeId; // 💡 공지사항 ID (nullable)
  final int? communityPostId; // 💡 커뮤니티 게시글 ID (nullable)
  final int memberId;
  final String authorName;
  final String createdAt;
  final String? updatedAt;
  final bool isDeleted;
  final String? deletionReason;

  Comment({
    required this.id,
    required this.content,
    this.noticeId,
    this.communityPostId,
    required this.memberId,
    required this.authorName,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletionReason,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      noticeId: json['noticeId'],
      communityPostId: json['communityPostId'],
      memberId: json['memberId'] ?? 0,
      authorName: json['authorName'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'],
      isDeleted: json['deleted'] ?? json['isDeleted'] ?? false,
      deletionReason: json['deletionReason'],
    );
  }
}
