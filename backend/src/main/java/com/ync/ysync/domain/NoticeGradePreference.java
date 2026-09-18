package com.ync.ysync.domain;

/**
 * 💡 회원이 직접 선택한 공지 알림 수신 대상입니다.
 *
 * 공지의 대상 학년({@link Grade})과는 별개의 개념입니다. 공지의 {@code Grade.ALL}은
 * "전체 학년에게 보내는 공지"를 뜻하지만, 회원의 {@code GENERAL_ONLY}는
 * "전체 공지만 받겠다"는 선택이며 학년 공지는 받지 않습니다.
 *
 * 미설정 상태는 이 enum의 값이 아니라 {@code null}로 표현합니다.
 * 사용자가 명시적으로 고른 {@code GENERAL_ONLY}와 시스템 상태인 미설정을 구분해야 하기 때문입니다.
 */
public enum NoticeGradePreference {
    GRADE_1,
    GRADE_2,
    GRADE_3,
    GENERAL_ONLY;

    /** 이 선택이 해당 공지 대상 학년의 알림을 받는지 판정합니다. */
    public boolean receives(Grade noticeTargetGrade) {
        if (noticeTargetGrade == null || noticeTargetGrade == Grade.ALL) {
            return true;
        }
        return switch (this) {
            case GRADE_1 -> noticeTargetGrade == Grade.GRADE_1;
            case GRADE_2 -> noticeTargetGrade == Grade.GRADE_2;
            case GRADE_3 -> noticeTargetGrade == Grade.GRADE_3;
            case GENERAL_ONLY -> false;
        };
    }

    /** 미설정(null) 회원까지 포함해 판정합니다. 미설정은 전체 공지만 받습니다. */
    public static boolean receives(NoticeGradePreference preference, Grade noticeTargetGrade) {
        if (noticeTargetGrade == null || noticeTargetGrade == Grade.ALL) {
            return true;
        }
        return preference != null && preference.receives(noticeTargetGrade);
    }
}
