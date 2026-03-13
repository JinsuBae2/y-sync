class Notice {
  final int id;
  final String title;
  final String content;
  final String author;
  final String noticeType;
  final String? aiSummary;
  final String createdAt;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.noticeType,
    this.aiSummary,
    required this.createdAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      author: json['author'],
      noticeType: json['noticeType'],
      aiSummary: json['aiSummary'],
      createdAt: json['createdAt'],
    );
  }
}
