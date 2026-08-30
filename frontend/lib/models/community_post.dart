import 'attachment.dart';

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
  final List<Attachment> attachments;

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
    List<Attachment>? attachments,
  }) : attachments =
           attachments ??
           (imageUrls ?? const [])
               .map(
                 (url) => Attachment(
                   url: url,
                   originalFilename: '이미지',
                   isImage: true,
                 ),
               )
               .toList();

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
      isDeleted: json['isDeleted'] ?? json['deleted'] ?? false,
      deletionReason: json['deletionReason'],
      targetGrade: json['targetGrade'] ?? 'ALL',
      isPinned: json['isPinned'] ?? json['pinned'] ?? false,
      viewCount: json['viewCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      imageUrls: json['imageUrls'] != null
          ? List<String>.from(json['imageUrls'])
          : null,
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
                .map(
                  (item) => Attachment.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : (json['imageUrls'] as List<dynamic>? ?? const [])
                .map(
                  (url) => Attachment(
                    url: url as String,
                    originalFilename: '이미지',
                    isImage: true,
                  ),
                )
                .toList(),
    );
  }
}
