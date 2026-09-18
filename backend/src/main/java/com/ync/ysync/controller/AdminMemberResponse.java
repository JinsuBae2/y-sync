package com.ync.ysync.controller;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.NoticeGradePreference;

import java.time.LocalDateTime;

public record AdminMemberResponse(
        Long id,
        String loginId,
        String name,
        MemberRole role,
        boolean noticeEnabled,
        boolean commentEnabled,
        boolean activated,
        boolean suspended,
        NoticeGradePreference noticeGradePreference,
        Integer gradeConfirmedYear,
        // 💡 관리자가 '올해 아직 확인하지 않은 회원'을 구분할 수 있도록 함께 내려줍니다.
        boolean gradeConfirmationRequired,
        LocalDateTime createdAt) {

    /** 학년도를 알 수 없는 호출부를 위한 형태입니다. 미확인 여부는 판정하지 않습니다. */
    public static AdminMemberResponse from(Member member) {
        return from(member, null);
    }

    public static AdminMemberResponse from(Member member, Integer currentAcademicYear) {
        boolean confirmationRequired = currentAcademicYear != null
                && (member.getNoticeGradePreference() == null
                || member.getGradeConfirmedYear() == null
                || member.getGradeConfirmedYear() < currentAcademicYear);

        return new AdminMemberResponse(
                member.getId(),
                member.getLoginId(),
                member.getName(),
                member.getRole(),
                member.isNoticeEnabled(),
                member.isCommentEnabled(),
                member.isActivated(),
                member.isSuspended(),
                member.getNoticeGradePreference(),
                member.getGradeConfirmedYear(),
                confirmationRequired,
                member.getCreatedAt());
    }
}
