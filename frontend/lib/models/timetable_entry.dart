class TimetableEntry {
  final int id;
  final String grade; // GRADE_1, GRADE_2, GRADE_3
  final String dayOfWeek; // MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY
  final String subjectName;
  final String professorName;
  final String classroom;
  final int startPeriod;
  final int endPeriod;

  TimetableEntry({
    required this.id,
    required this.grade,
    required this.dayOfWeek,
    required this.subjectName,
    required this.professorName,
    required this.classroom,
    required this.startPeriod,
    required this.endPeriod,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      id: json['id'],
      grade: json['grade'] ?? 'PERSONAL',
      dayOfWeek: json['dayOfWeek'],
      subjectName: json['subjectName'],
      professorName: json['professorName'],
      classroom: json['classroom'],
      startPeriod: json['startPeriod'],
      endPeriod: json['endPeriod'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'grade': grade,
      'dayOfWeek': dayOfWeek,
      'subjectName': subjectName,
      'professorName': professorName,
      'classroom': classroom,
      'startPeriod': startPeriod,
      'endPeriod': endPeriod,
    };
  }
}
