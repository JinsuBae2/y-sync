import 'notice_grade_preference.dart';

/// 💡 학년별 알림 전환 시점을 판단하기 위한 집계입니다.
///
/// 전환하면 [unsetCount]명이 학년 공지 알림을 받지 못합니다. 그 숫자를 먼저 보고
/// 전환 여부를 정할 수 있도록 관리자 화면에 표시합니다.
class NoticeGradeStats {
  const NoticeGradeStats({
    required this.currentAcademicYear,
    required this.noticeTargetCount,
    required this.unsetCount,
    required this.selectedCount,
    required this.needsConfirmationCount,
    required this.countsByPreference,
  });

  /// 서버가 계산한 현재 학년도입니다.
  final int currentAcademicYear;

  /// 공지 알림 대상 회원 수입니다. 활성 회원이면서 공지 알림을 켠 회원만 셉니다.
  final int noticeTargetCount;

  /// 아직 선택하지 않은 회원 수입니다. 전환하면 학년 공지를 받지 못합니다.
  final int unsetCount;

  /// 선택을 마친 회원 수입니다.
  final int selectedCount;

  /// 올해 확인이 필요한 회원 수입니다. 미설정 회원을 포함합니다.
  final int needsConfirmationCount;

  final Map<NoticeGradePreference, int> countsByPreference;

  int get selectedPercent => noticeTargetCount == 0
      ? 0
      : (selectedCount * 100 / noticeTargetCount).round();

  factory NoticeGradeStats.fromJson(Map<String, dynamic> json) {
    final raw = (json['countsByPreference'] as Map?) ?? const {};
    final counts = <NoticeGradePreference, int>{};
    for (final preference in NoticeGradePreference.values) {
      counts[preference] = (raw[preference.wireValue] as int?) ?? 0;
    }

    return NoticeGradeStats(
      currentAcademicYear: json['currentAcademicYear'] ?? 0,
      noticeTargetCount: json['noticeTargetCount'] ?? 0,
      unsetCount: json['unsetCount'] ?? 0,
      selectedCount: json['selectedCount'] ?? 0,
      needsConfirmationCount: json['needsConfirmationCount'] ?? 0,
      countsByPreference: counts,
    );
  }
}
