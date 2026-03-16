class Notice {
  final int id;
  final String title;
  final String content;
  final String authorName;
  final String noticeType;
  final String? aiSummary;
  final String createdAt;
  final String? updatedAt;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.noticeType,
    this.aiSummary,
    required this.createdAt,
    this.updatedAt,
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
    );
  }
}
