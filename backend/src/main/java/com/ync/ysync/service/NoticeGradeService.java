package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.NoticeGradePreference;
import com.ync.ysync.controller.NoticeGradeStatsResponse;
import com.ync.ysync.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.Map;

/**
 * 💡 공지 알림 수신 학년의 선택과 학년도 확인을 담당합니다.
 *
 * 학번으로 학년을 추정하거나 매년 자동으로 진급시키지 않습니다. 학생이 명시적으로 선택한 값만 저장하며,
 * 선택값과 확인 학년도는 항상 같은 트랜잭션에서 함께 저장합니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NoticeGradeService {

    private final MemberRepository memberRepository;
    private final AcademicYearCalculator academicYearCalculator;

    /**
     * 본인의 공지 알림 수신 학년을 선택하고 현재 학년도로 확인 처리합니다.
     *
     * 같은 학년을 다시 선택하거나 '전체 공지만 받기'를 다시 선택해도 정상 처리하며,
     * 이 경우 확인 학년도만 최신으로 갱신됩니다.
     */
    @Transactional
    public Member updateOwnPreference(Long memberId, NoticeGradePreference preference) {
        if (preference == null) {
            throw new IllegalArgumentException("공지 알림 수신 대상을 선택해 주세요.");
        }
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        applyPreference(member, preference);
        log.info("공지 알림 수신 학년 변경 - 회원 ID: {}, 선택: {}, 확인 학년도: {}",
                memberId, preference, member.getGradeConfirmedYear());
        return memberRepository.save(member);
    }

    /**
     * 선택값과 확인 학년도를 함께 반영합니다. 관리자 예외 수정도 현재 학년도 확인으로 처리합니다.
     */
    public void applyPreference(Member member, NoticeGradePreference preference) {
        member.setNoticeGradePreference(preference);
        member.setGradeConfirmedYear(academicYearCalculator.currentAcademicYear());
    }

    /** 서버가 계산한 현재 학년도입니다. */
    public int currentAcademicYear() {
        return academicYearCalculator.currentAcademicYear();
    }

    /**
     * 학년 확인 안내가 필요한 상태인지 판정합니다.
     *
     * 선택이 미설정이거나, 확인 이력이 없거나, 마지막 확인 학년도가 현재 학년도보다 이전이면 필요합니다.
     * '전체 공지만 받기'를 고른 회원도 새 학년도에는 다시 확인 대상입니다.
     */
    public boolean confirmationRequired(Member member) {
        return confirmationRequired(member, currentAcademicYear());
    }

    public boolean confirmationRequired(Member member, int currentAcademicYear) {
        return member.getNoticeGradePreference() == null
                || member.getGradeConfirmedYear() == null
                || member.getGradeConfirmedYear() < currentAcademicYear;
    }

    /**
     * 학년별 알림 전환 시점을 판단하기 위한 집계입니다.
     *
     * 전환하면 미설정 회원은 학년 공지 알림을 받지 못하므로, 그 인원을 먼저 확인하고 정할 수 있어야 합니다.
     * 회원 전체를 메모리로 읽지 않고 DB에서 집계합니다.
     */
    @Transactional(readOnly = true)
    public NoticeGradeStatsResponse collectStats() {
        int currentAcademicYear = currentAcademicYear();

        Map<NoticeGradePreference, Long> counts = new HashMap<>();
        for (Object[] row : memberRepository.countNoticeTargetsByGradePreference()) {
            NoticeGradePreference preference = (NoticeGradePreference) row[0];
            if (preference == null) {
                continue; // 미설정은 전체 수에서 빼는 방식으로 계산합니다.
            }
            counts.put(preference, ((Number) row[1]).longValue());
        }

        return NoticeGradeStatsResponse.of(
                currentAcademicYear,
                memberRepository.countNoticeTargets(),
                memberRepository.countNoticeTargetsNeedingConfirmation(currentAcademicYear),
                counts);
    }
}
