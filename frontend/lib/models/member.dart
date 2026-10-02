import 'notice_grade_preference.dart';

class Member {
  final int id;
  final String loginId;
  final String name;
  final String role;
  final bool noticeEnabled;
  final bool commentEnabled;
  final bool isActivated; // 💡 가입(활성화) 여부 추가

  /// 💡 가입에 사용된 학교 메일입니다. 관리자 회원 조회에서만 내려오며 본인 조회에는 없습니다.
  ///    학교 메일은 사용자 정의 ID라 학번에서 유도할 수 없으므로, 학번 도용 신고를 받았을 때
  ///    가해자를 특정하는 단서로 씁니다.
  final String? email;

  /// 💡 공지 알림 수신 대상 선택입니다. null은 '미설정'입니다.
  final NoticeGradePreference? noticeGradePreference;

  /// 서버가 계산한 마지막 확인 학년도입니다. null은 확인 이력이 없음을 뜻합니다.
  final int? gradeConfirmedYear;

  /// 서버가 계산한 현재 학년도입니다. 단말기 시각에 의존하지 않습니다.
  final int? currentAcademicYear;

  /// 학년 확인 안내가 필요한 상태인지 서버가 판정한 결과입니다.
  final bool gradeConfirmationRequired;

  Member({
    required this.id,
    required this.loginId,
    required this.name,
    required this.role,
    required this.noticeEnabled,
    required this.commentEnabled,
    required this.isActivated,
    this.email,
    this.noticeGradePreference,
    this.gradeConfirmedYear,
    this.currentAcademicYear,
    this.gradeConfirmationRequired = false,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? 0,
      loginId: json['loginId'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      noticeEnabled: json['noticeEnabled'] ?? true,
      commentEnabled: json['commentEnabled'] ?? true,
      isActivated: json['activated'] ?? json['isActivated'] ?? false,
      email: json['email'] as String?,
      noticeGradePreference: NoticeGradePreference.fromWire(
        json['noticeGradePreference'] as String?,
      ),
      gradeConfirmedYear: json['gradeConfirmedYear'] as int?,
      currentAcademicYear: json['currentAcademicYear'] as int?,
      // 💡 이 필드를 내려주지 않는 구버전 서버와도 동작하도록 기본값은 false입니다.
      gradeConfirmationRequired: json['gradeConfirmationRequired'] ?? false,
    );
  }
}
