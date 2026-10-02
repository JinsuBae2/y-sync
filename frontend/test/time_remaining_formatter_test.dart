import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/utils/time_remaining_formatter.dart';

void main() {
  test('남은 분을 사람이 읽기 쉬운 시간과 분으로 표시한다', () {
    expect(formatMinutesUntil(243), '4시간 3분 후');
    expect(formatMinutesUntil(120), '2시간 후');
    expect(formatMinutesUntil(45), '45분 후');
  });

  test('수업 시작 경계에서는 음수 시간을 표시하지 않는다', () {
    expect(formatMinutesUntil(0), '곧 시작');
    expect(formatMinutesUntil(-1), '곧 시작');
  });
}
