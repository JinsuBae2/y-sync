enum CommentDeletedBy { author, admin }

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
  final CommentDeletedBy? deletedBy;
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
    this.deletedBy,
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
      isDeleted: json['isDeleted'] ?? json['deleted'] ?? false,
      deletionReason: json['deletionReason'],
      deletedBy: _parseDeletedBy(
        json['deletedBy'],
        deletionReason: json['deletionReason'],
      ),
      parentId: json['parentId'],
      children: json['children'] != null
          ? (json['children'] as List).map((i) => Comment.fromJson(i)).toList()
          : null,
    );
  }

  static CommentDeletedBy? _parseDeletedBy(
    Object? value, {
    required Object? deletionReason,
  }) {
    switch (value?.toString().toUpperCase()) {
      case 'AUTHOR':
        return CommentDeletedBy.author;
      case 'ADMIN':
        return CommentDeletedBy.admin;
    }

    // 구형 응답 호환: 관리자 삭제는 사유가 있고, 작성자 삭제는 사유가 없습니다.
    if (deletionReason is String && deletionReason.trim().isNotEmpty) {
      return CommentDeletedBy.admin;
    }
    return null;
  }
}
