class CalendarEvent {
  final int id;
  final String title;
  final String? description;
  final String startDate; // yyyy-MM-dd
  final String endDate; // yyyy-MM-dd
  final String type; // ACADEMIC, NOTICE
  final int? noticeId;
  final String color;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.noticeId,
    required this.color,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startDate: json['startDate'],
      endDate: json['endDate'],
      type: json['type'] ?? 'ACADEMIC',
      noticeId: json['noticeId'],
      color: json['color'] ?? '#4A90E2',
    );
  }
}
