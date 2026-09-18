package com.ync.ysync.service;

import com.ync.ysync.controller.NoticeGradeStatsResponse;
import com.ync.ysync.domain.NoticeGradePreference;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.LocalDate;
import java.time.MonthDay;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

/**
 * 💡 학년별 알림 전환 시점을 판단하는 집계를 고정하는 테스트입니다.
 *
 * 전환하면 미설정 회원은 학년 공지 알림을 받지 못하므로, 그 인원이 정확해야 합니다.
 * 미설정은 DB에 값이 없어 집계 행으로 돌아오지 않으므로 전체 수에서 빼는 방식으로 셉니다.
 */
@ExtendWith(MockitoExtension.class)
class NoticeGradeStatsTest {

    private static final int CURRENT_YEAR = 2027;

    @Mock private MemberRepository memberRepository;

    private NoticeGradeService noticeGradeService;

    @BeforeEach
    void setUp() {
        Clock fixed = Clock.fixed(
                ZonedDateTime.of(LocalDate.of(CURRENT_YEAR, 5, 1).atStartOfDay(),
                        ZoneId.of("Asia/Seoul")).toInstant(),
                ZoneId.of("Asia/Seoul"));
        noticeGradeService = new NoticeGradeService(
                memberRepository, new AcademicYearCalculator(MonthDay.of(3, 1), fixed));
    }

    @Test
    void 선택값별_인원과_미설정_인원을_함께_집계한다() {
        when(memberRepository.countNoticeTargets()).thenReturn(300L);
        when(memberRepository.countNoticeTargetsByGradePreference()).thenReturn(List.of(
                new Object[]{NoticeGradePreference.GRADE_1, 60L},
                new Object[]{NoticeGradePreference.GRADE_2, 70L},
                new Object[]{NoticeGradePreference.GRADE_3, 30L},
                new Object[]{NoticeGradePreference.GENERAL_ONLY, 20L}));
        when(memberRepository.countNoticeTargetsNeedingConfirmation(CURRENT_YEAR)).thenReturn(150L);

        NoticeGradeStatsResponse stats = noticeGradeService.collectStats();

        assertThat(stats.currentAcademicYear()).isEqualTo(CURRENT_YEAR);
        assertThat(stats.noticeTargetCount()).isEqualTo(300);
        assertThat(stats.selectedCount()).isEqualTo(180);
        // 300명 중 180명이 골랐으므로 전환 시 120명이 학년 공지를 받지 못한다.
        assertThat(stats.unsetCount()).isEqualTo(120);
        assertThat(stats.needsConfirmationCount()).isEqualTo(150);
        assertThat(stats.selectedPercent()).isEqualTo(60);
        assertThat(stats.countsByPreference())
                .containsEntry(NoticeGradePreference.GRADE_1, 60L)
                .containsEntry(NoticeGradePreference.GENERAL_ONLY, 20L);
    }

    @Test
    void 아무도_선택하지_않았으면_전원이_미설정이다() {
        when(memberRepository.countNoticeTargets()).thenReturn(300L);
        when(memberRepository.countNoticeTargetsByGradePreference()).thenReturn(List.of());
        when(memberRepository.countNoticeTargetsNeedingConfirmation(CURRENT_YEAR)).thenReturn(300L);

        NoticeGradeStatsResponse stats = noticeGradeService.collectStats();

        assertThat(stats.unsetCount()).isEqualTo(300);
        assertThat(stats.selectedCount()).isZero();
        assertThat(stats.selectedPercent()).isZero();
        // 값이 없는 선택지도 0으로 채워져 화면에서 빈칸이 생기지 않는다.
        assertThat(stats.countsByPreference()).hasSize(NoticeGradePreference.values().length);
        assertThat(stats.countsByPreference().values()).allMatch(count -> count == 0L);
    }

    @Test
    void 미설정으로_돌아온_집계_행은_선택_인원에_넣지_않는다() {
        when(memberRepository.countNoticeTargets()).thenReturn(100L);
        when(memberRepository.countNoticeTargetsByGradePreference()).thenReturn(List.of(
                new Object[]{null, 40L},
                new Object[]{NoticeGradePreference.GRADE_1, 60L}));
        when(memberRepository.countNoticeTargetsNeedingConfirmation(CURRENT_YEAR)).thenReturn(40L);

        NoticeGradeStatsResponse stats = noticeGradeService.collectStats();

        assertThat(stats.selectedCount()).isEqualTo(60);
        assertThat(stats.unsetCount()).isEqualTo(40);
    }

    @Test
    void 알림_대상이_없으면_비율은_영이고_음수가_되지_않는다() {
        when(memberRepository.countNoticeTargets()).thenReturn(0L);
        when(memberRepository.countNoticeTargetsByGradePreference()).thenReturn(List.of());
        when(memberRepository.countNoticeTargetsNeedingConfirmation(CURRENT_YEAR)).thenReturn(0L);

        NoticeGradeStatsResponse stats = noticeGradeService.collectStats();

        assertThat(stats.noticeTargetCount()).isZero();
        assertThat(stats.unsetCount()).isZero();
        assertThat(stats.selectedPercent()).isZero();
    }
}
