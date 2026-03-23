// 💡 커뮤니티 게시글 모델 클래스입니다.
class CommunityPost {
  final int id;
  final String category;
  final String title;
  final String content;
  final bool anonymous;
  final String authorName;
  final int memberId;
  final String createdAt;
  final bool isDeleted;
  final String? deletionReason;

  CommunityPost({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.anonymous,
    required this.authorName,
    required this.memberId,
    required this.createdAt,
    this.isDeleted = false,
    this.deletionReason,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'],
      category: json['category'],
      title: json['title'],
      content: json['content'],
      anonymous: json['anonymous'],
      authorName: json['authorName'],
      memberId: json['memberId'],
      createdAt: json['createdAt'],
      isDeleted: json['deleted'] ?? json['isDeleted'] ?? false,
      deletionReason: json['deletionReason'],
    );
  }
}
