class Comment {
  final int id;
  final String content;
  final int? noticeId; // 💡 공지사항 ID (nullable)
  final int? communityPostId; // 💡 커뮤니티 게시글 ID (nullable)
  final int memberId;
  final String authorName;
  final String createdAt;
  final String? updatedAt;

  Comment({
    required this.id,
    required this.content,
    this.noticeId,
    this.communityPostId,
    required this.memberId,
    required this.authorName,
    required this.createdAt,
    this.updatedAt,
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
    );
  }
}
