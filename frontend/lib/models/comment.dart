class Comment {
  final int id;
  final String content;
  final int noticeId;
  final int memberId;
  final String authorName;
  final String createdAt;
  final String? updatedAt;

  Comment({
    required this.id,
    required this.content,
    required this.noticeId,
    required this.memberId,
    required this.authorName,
    required this.createdAt,
    this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      content: json['content'],
      noticeId: json['noticeId'],
      memberId: json['memberId'],
      authorName: json['authorName'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}
