class Notice {
  final int id;
  final String title;
  final String content;
  final String authorName;
  final String noticeType;
  final String? aiSummary;
  final String createdAt;
  final String? updatedAt;
  // 💡 새로 추가된 필드들
  final String targetGrade;
  final bool isPinned;
  final int viewCount;
  final int commentCount;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.noticeType,
    this.aiSummary,
    required this.createdAt,
    this.updatedAt,
    this.targetGrade = 'ALL',
    this.isPinned = false,
    this.viewCount = 0,
    this.commentCount = 0,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      authorName: json['authorName'],
      noticeType: json['noticeType'],
      aiSummary: json['aiSummary'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      targetGrade: json['targetGrade'] ?? 'ALL',
      isPinned: json['isPinned'] ?? false,
      viewCount: json['viewCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
    );
  }
}
