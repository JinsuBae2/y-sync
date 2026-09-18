package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.NoticeGradePreference;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.Clock;
import java.time.LocalDate;
import java.time.MonthDay;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * 💡 학년 선택과 학년도 확인 규칙을 고정하는 테스트입니다.
 *
 * 자동 진급은 하지 않으며, 같은 학년을 다시 골라도 확인은 완료 처리되어야 합니다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NoticeGradeServiceTest {

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
        when(memberRepository.save(any(Member.class))).thenAnswer(call -> call.getArgument(0));
    }

    private Member member(NoticeGradePreference preference, Integer confirmedYear) {
        Member member = Member.builder()
                .loginId("2305001").password("encoded").name("학생")
                .role(MemberRole.USER).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(true).isSuspended(false)
                .build();
        member.setNoticeGradePreference(preference);
        member.setGradeConfirmedYear(confirmedYear);
        return member;
    }

    @Test
    void 미설정_회원은_확인이_필요하다() {
        assertThat(noticeGradeService.confirmationRequired(member(null, null), CURRENT_YEAR)).isTrue();
    }

    @Test
    void 확인_이력이_없으면_선택값이_있어도_확인이_필요하다() {
        assertThat(noticeGradeService.confirmationRequired(
                member(NoticeGradePreference.GRADE_1, null), CURRENT_YEAR)).isTrue();
    }

    @Test
    void 지난_학년도에_확인했다면_새_학년도에_다시_확인한다() {
        assertThat(noticeGradeService.confirmationRequired(
                member(NoticeGradePreference.GRADE_1, CURRENT_YEAR - 1), CURRENT_YEAR)).isTrue();
    }

    @Test
    void 올해_확인을_마쳤다면_다시_묻지_않는다() {
        assertThat(noticeGradeService.confirmationRequired(
                member(NoticeGradePreference.GRADE_2, CURRENT_YEAR), CURRENT_YEAR)).isFalse();
    }

    @Test
    void 전체_공지만_받기를_고른_회원도_새_학년도에는_다시_확인한다() {
        assertThat(noticeGradeService.confirmationRequired(
                member(NoticeGradePreference.GENERAL_ONLY, CURRENT_YEAR - 1), CURRENT_YEAR)).isTrue();
    }

    @ParameterizedTest
    @EnumSource(NoticeGradePreference.class)
    void 네_선택지_모두_저장되고_확인_학년도가_갱신된다(NoticeGradePreference preference) {
        when(memberRepository.findById(1L)).thenReturn(Optional.of(member(null, null)));

        Member saved = noticeGradeService.updateOwnPreference(1L, preference);

        assertThat(saved.getNoticeGradePreference()).isEqualTo(preference);
        assertThat(saved.getGradeConfirmedYear()).isEqualTo(CURRENT_YEAR);
        assertThat(noticeGradeService.confirmationRequired(saved, CURRENT_YEAR)).isFalse();
    }

    @Test
    void 같은_학년을_다시_선택해도_확인_학년도만_갱신된다() {
        when(memberRepository.findById(1L))
                .thenReturn(Optional.of(member(NoticeGradePreference.GRADE_1, CURRENT_YEAR - 1)));

        Member saved = noticeGradeService.updateOwnPreference(1L, NoticeGradePreference.GRADE_1);

        assertThat(saved.getNoticeGradePreference()).isEqualTo(NoticeGradePreference.GRADE_1);
        assertThat(saved.getGradeConfirmedYear()).isEqualTo(CURRENT_YEAR);
    }

    @Test
    void 자동으로_다음_학년으로_올리지_않는다() {
        Member lastYear = member(NoticeGradePreference.GRADE_1, CURRENT_YEAR - 1);

        assertThat(noticeGradeService.confirmationRequired(lastYear, CURRENT_YEAR)).isTrue();
        // 확인이 필요하다고만 알릴 뿐, 조회 과정에서 선택값이 바뀌어서는 안 된다.
        assertThat(lastYear.getNoticeGradePreference()).isEqualTo(NoticeGradePreference.GRADE_1);
        assertThat(lastYear.getGradeConfirmedYear()).isEqualTo(CURRENT_YEAR - 1);
    }

    @Test
    void 선택값_없이는_저장하지_않는다() {
        assertThatThrownBy(() -> noticeGradeService.updateOwnPreference(1L, null))
                .isInstanceOf(IllegalArgumentException.class);

        verifyNoInteractions(memberRepository);
    }
}
