/// 인앱 알림 데이터를 나타내는 모델입니다.
class AppNotification {
  final int id;
  final String title;
  final String body;
  final String targetType;
  final int targetId;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      targetType: json['targetType'] as String? ?? '',
      targetId: json['targetId'] as int? ?? 0,
      isRead: (json['isRead'] ?? json['read']) as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      targetType: targetType,
      targetId: targetId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
