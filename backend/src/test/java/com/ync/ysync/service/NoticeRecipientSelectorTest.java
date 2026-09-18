package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeGradePreference;
import com.ync.ysync.domain.NoticeType;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

/**
 * 💡 공지 알림 수신자 선정 규칙을 기획서의 수신 표대로 고정하는 테스트입니다.
 *
 * 공지의 ALL(전체 학년 대상)과 회원의 GENERAL_ONLY(전체 공지만 받기)는 다른 개념이며,
 * 미설정 회원은 전체 공지만 받습니다. 관리자도 같은 규칙을 적용받습니다.
 */
@ExtendWith(MockitoExtension.class)
class NoticeRecipientSelectorTest {

    @Mock private MemberRepository memberRepository;

    private NoticeRecipientSelector selector;

    @BeforeEach
    void setUp() {
        selector = new NoticeRecipientSelector(memberRepository);
        ReflectionTestUtils.setField(selector, "gradeFilterEnabled", true);
    }

    private Member member(String loginId, NoticeGradePreference preference, MemberRole role) {
        Member member = Member.builder()
                .loginId(loginId).password("encoded").name(loginId)
                .role(role).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(true).isSuspended(false)
                .build();
        member.setNoticeGradePreference(preference);
        return member;
    }

    private Notice notice(Grade targetGrade) {
        return new Notice("제목", "내용", null, NoticeType.NOTICE, null, targetGrade, false, null, null);
    }

    private List<Member> allPreferenceMembers() {
        return List.of(
                member("grade1", NoticeGradePreference.GRADE_1, MemberRole.USER),
                member("grade2", NoticeGradePreference.GRADE_2, MemberRole.USER),
                member("grade3", NoticeGradePreference.GRADE_3, MemberRole.USER),
                member("general", NoticeGradePreference.GENERAL_ONLY, MemberRole.USER),
                member("unset", null, MemberRole.USER));
    }

    @ParameterizedTest(name = "{0} 공지 → {1}")
    @CsvSource(delimiter = '|', value = {
            "ALL     | grade1,grade2,grade3,general,unset",
            "GRADE_1 | grade1",
            "GRADE_2 | grade2",
            "GRADE_3 | grade3",
    })
    void 공지_대상_학년별_수신자가_기획서_표와_일치한다(String targetGrade, String expected) {
        when(memberRepository.findAllByIsActivatedTrueAndNoticeEnabledTrue())
                .thenReturn(allPreferenceMembers());

        List<Member> recipients = selector.selectRecipients(notice(Grade.valueOf(targetGrade)));

        assertThat(recipients).extracting(Member::getLoginId)
                .containsExactlyInAnyOrder(expected.split(","));
    }

    @Test
    void 관리자도_같은_학년_규칙을_적용받는다() {
        when(memberRepository.findAllByIsActivatedTrueAndNoticeEnabledTrue()).thenReturn(List.of(
                member("admin1", NoticeGradePreference.GRADE_1, MemberRole.ADMIN),
                member("admin2", NoticeGradePreference.GRADE_2, MemberRole.SUPER_ADMIN)));

        assertThat(selector.selectRecipients(notice(Grade.GRADE_1)))
                .extracting(Member::getLoginId).containsExactly("admin1");
    }

    @Test
    void 대상_학년이_비어_있으면_전체_공지로_처리한다() {
        when(memberRepository.findAllByIsActivatedTrueAndNoticeEnabledTrue())
                .thenReturn(allPreferenceMembers());

        assertThat(selector.selectRecipients(notice(null))).hasSize(5);
    }

    @Test
    void 필터를_끄면_기존_발송_범위를_그대로_유지한다() {
        ReflectionTestUtils.setField(selector, "gradeFilterEnabled", false);
        when(memberRepository.findAllByIsActivatedTrueAndNoticeEnabledTrue())
                .thenReturn(allPreferenceMembers());

        // 도입 1단계와 장애 시 복구 경로. 학년 공지도 기존처럼 전원에게 나간다.
        assertThat(selector.selectRecipients(notice(Grade.GRADE_1))).hasSize(5);
    }
}
