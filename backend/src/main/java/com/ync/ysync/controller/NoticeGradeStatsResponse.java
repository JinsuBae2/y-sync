package com.ync.ysync.controller;

import com.ync.ysync.domain.NoticeGradePreference;

import java.util.EnumMap;
import java.util.Map;

/**
 * 💡 학년별 알림 전환 시점을 판단하기 위한 집계입니다.
 *
 * 전환하면 미설정 회원은 학년 공지 알림을 받지 못합니다. 그 영향 범위를 숫자로 먼저 보고
 * 전환 여부를 정할 수 있도록, 알림 대상 회원 중 아직 선택하지 않은 인원을 함께 제공합니다.
 *
 * 모수는 '공지 알림을 받을 수 있는 회원'(활성 + 공지 알림 동의)입니다. 공지 알림을 꺼 둔 회원은
 * 전환과 무관하게 알림을 받지 않으므로 판단에서 제외합니다.
 *
 * @param currentAcademicYear      서버가 계산한 현재 학년도
 * @param noticeTargetCount        공지 알림 대상 회원 수 (모수)
 * @param unsetCount               아직 선택하지 않은 회원 수. 전환 시 학년 공지를 받지 못합니다.
 * @param selectedCount            선택을 마친 회원 수
 * @param needsConfirmationCount   올해 확인이 필요한 회원 수 (미설정 포함).
 *                                 확인하지 않아도 이전 선택 기준으로 알림은 계속 받습니다.
 * @param countsByPreference       선택값별 회원 수. 미설정은 이 표에 포함하지 않습니다.
 */
public record NoticeGradeStatsResponse(
        int currentAcademicYear,
        long noticeTargetCount,
        long unsetCount,
        long selectedCount,
        long needsConfirmationCount,
        Map<NoticeGradePreference, Long> countsByPreference) {

    public static NoticeGradeStatsResponse of(
            int currentAcademicYear,
            long noticeTargetCount,
            long needsConfirmationCount,
            Map<NoticeGradePreference, Long> countsByPreference) {

        Map<NoticeGradePreference, Long> counts = new EnumMap<>(NoticeGradePreference.class);
        for (NoticeGradePreference preference : NoticeGradePreference.values()) {
            counts.put(preference, countsByPreference.getOrDefault(preference, 0L));
        }

        long selected = counts.values().stream().mapToLong(Long::longValue).sum();
        return new NoticeGradeStatsResponse(
                currentAcademicYear,
                noticeTargetCount,
                Math.max(0, noticeTargetCount - selected),
                selected,
                needsConfirmationCount,
                counts);
    }

    /** 선택을 마친 회원 비율(%)입니다. 대상이 없으면 0을 돌려줍니다. */
    public int selectedPercent() {
        return noticeTargetCount == 0 ? 0 : (int) Math.round(selectedCount * 100.0 / noticeTargetCount);
    }
}
