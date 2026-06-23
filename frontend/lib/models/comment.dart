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
  final int? parentId; // 💡 부모 댓글 ID
  final List<Comment>? children; // 💡 대댓글(자식) 목록

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
    this.parentId,
    this.children,
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
      parentId: json['parentId'],
      children: json['children'] != null
          ? (json['children'] as List).map((i) => Comment.fromJson(i)).toList()
          : null,
    );
  }
}
