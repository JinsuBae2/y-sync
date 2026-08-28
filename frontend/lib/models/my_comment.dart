// 💡 마이페이지에서 내가 쓴 댓글과 대상 게시글 정보를 담는 모델입니다.
class MyComment {
  final int id;
  final String content;
  final String postTitle;
  final String category;
  final int postId;
  final String createdAt;
  final bool isDeleted;
  final String? deletionReason;
  final String? deletedBy;

  MyComment({
    required this.id,
    required this.content,
    required this.postTitle,
    required this.category,
    required this.postId,
    required this.createdAt,
    this.isDeleted = false,
    this.deletionReason,
    this.deletedBy,
  });

  factory MyComment.fromJson(Map<String, dynamic> json) {
    return MyComment(
      id: json['id'],
      content: json['content'],
      postTitle: json['postTitle'],
      category: json['category'],
      postId: json['postId'],
      createdAt: json['createdAt'],
      isDeleted: json['isDeleted'] ?? json['deleted'] ?? false,
      deletionReason: json['deletionReason'],
      deletedBy: json['deletedBy'],
    );
  }

  bool get isDeletedByAdmin {
    if (deletedBy != null) {
      return deletedBy!.toUpperCase() == 'ADMIN';
    }
    return deletionReason?.trim().isNotEmpty ?? false;
  }
}
