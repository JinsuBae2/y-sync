String formatMinutesUntil(int minutes) {
  if (minutes <= 0) return '곧 시작';

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours == 0) return '$remainingMinutes분 후';
  if (remainingMinutes == 0) return '$hours시간 후';
  return '$hours시간 $remainingMinutes분 후';
}
