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

  MyComment({
    required this.id,
    required this.content,
    required this.postTitle,
    required this.category,
    required this.postId,
    required this.createdAt,
    this.isDeleted = false,
    this.deletionReason,
  });

  factory MyComment.fromJson(Map<String, dynamic> json) {
    return MyComment(
      id: json['id'],
      content: json['content'],
      postTitle: json['postTitle'],
      category: json['category'],
      postId: json['postId'],
      createdAt: json['createdAt'],
      isDeleted: json['deleted'] ?? json['isDeleted'] ?? false,
      deletionReason: json['deletionReason'],
    );
  }
}
