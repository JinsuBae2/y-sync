package com.ync.ysync.controller;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;

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
        LocalDateTime createdAt) {

    public static AdminMemberResponse from(Member member) {
        return new AdminMemberResponse(
                member.getId(),
                member.getLoginId(),
                member.getName(),
                member.getRole(),
                member.isNoticeEnabled(),
                member.isCommentEnabled(),
                member.isActivated(),
                member.isSuspended(),
                member.getCreatedAt());
    }
}
