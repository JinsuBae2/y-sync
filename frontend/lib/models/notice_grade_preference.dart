/// 💡 회원이 직접 고른 공지 알림 수신 대상입니다.
///
/// 공지의 대상 학년(`ALL`, `GRADE_1` …)과는 다른 개념입니다. 공지의 `ALL`은 "전체 학년에게 보내는
/// 공지"를 뜻하지만, 회원의 [generalOnly]는 "전체 공지만 받겠다"는 선택이며 학년 공지는 받지 않습니다.
///
/// 아직 아무것도 고르지 않은 '미설정'은 이 enum의 값이 아니라 `null`로 표현합니다.
/// 사용자가 명시적으로 고른 [generalOnly]와 시스템 상태인 미설정은 구분해야 합니다.
enum NoticeGradePreference {
  grade1('GRADE_1', '1학년'),
  grade2('GRADE_2', '2학년'),
  grade3('GRADE_3', '3학년'),
  generalOnly('GENERAL_ONLY', '전체 공지만 받기');

  const NoticeGradePreference(this.wireValue, this.label);

  /// 서버와 주고받는 값입니다.
  final String wireValue;

  /// 화면에 표시하는 이름입니다.
  final String label;

  static NoticeGradePreference? fromWire(String? value) {
    if (value == null) return null;
    for (final preference in NoticeGradePreference.values) {
      if (preference.wireValue == value) return preference;
    }
    // 서버가 새 값을 추가해도 앱이 깨지지 않도록 미설정으로 취급합니다.
    return null;
  }

  /// 미설정을 포함한 표시 문구입니다.
  static String labelOf(NoticeGradePreference? preference) =>
      preference?.label ?? '미설정';
}
