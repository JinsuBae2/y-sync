class Scrap {
  final int scrapId;
  final String targetType;
  final int targetId;
  final String? category;
  final String title;
  final String authorName;
  final DateTime postCreatedAt;
  final int commentCount;
  final DateTime scrappedAt;

  Scrap({
    required this.scrapId,
    required this.targetType,
    required this.targetId,
    this.category,
    required this.title,
    required this.authorName,
    required this.postCreatedAt,
    required this.commentCount,
    required this.scrappedAt,
  });

  factory Scrap.fromJson(Map<String, dynamic> json) {
    return Scrap(
      scrapId: json['scrapId'],
      targetType: json['targetType'],
      targetId: json['targetId'],
      category: json['category'],
      title: json['title'],
      authorName: json['authorName'],
      postCreatedAt: DateTime.parse(json['postCreatedAt']),
      commentCount: json['commentCount'] ?? 0,
      scrappedAt: DateTime.parse(json['scrappedAt']),
    );
  }
}
