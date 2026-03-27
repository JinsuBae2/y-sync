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
  // 💡 새로 추가된 필드들
  final String targetGrade;
  final bool isPinned;
  final int viewCount;
  final int commentCount;
  final List<String>? imageUrls; // 💡 이미지 URL 목록 추가

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
    this.targetGrade = 'ALL',
    this.isPinned = false,
    this.viewCount = 0,
    this.commentCount = 0,
    this.imageUrls,
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
      targetGrade: json['targetGrade'] ?? 'ALL',
      isPinned: json['isPinned'] ?? false,
      viewCount: json['viewCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      imageUrls: json['imageUrls'] != null ? List<String>.from(json['imageUrls']) : null,
    );
  }
}
