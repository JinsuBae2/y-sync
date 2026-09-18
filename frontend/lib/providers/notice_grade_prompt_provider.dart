import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 💡 학년 확인 안내를 이미 보여준 학년도를 기억합니다.
///
/// 같은 사용 세션에서 안내를 반복하지 않되, 학년도가 바뀌면 다시 안내 대상이 되도록
/// '보여줬다' 플래그가 아니라 '어느 학년도에 보여줬는지'를 저장합니다.
/// 앱을 다시 실행하면 이 상태는 초기화되므로 '나중에'를 고른 사용자에게 다음 실행 때 다시 안내됩니다.
class NoticeGradePromptNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  /// 해당 학년도 안내를 지금 보여줘야 하는지 판단합니다.
  bool shouldPrompt(int academicYear) => state != academicYear;

  void markPrompted(int academicYear) => state = academicYear;

  /// 계정이 바뀌면 이전 계정의 안내 이력을 남기지 않습니다.
  void reset() => state = null;
}

final noticeGradePromptProvider =
    NotifierProvider<NoticeGradePromptNotifier, int?>(
      NoticeGradePromptNotifier.new,
    );
