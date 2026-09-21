package com.ync.ysync.service;

import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verifyNoInteractions;

/**
 * 💡 회원가입의 비밀번호 정책 적용을 고정하는 회귀 테스트입니다.
 *
 * 정책(`validatePassword`)은 구현되어 있었지만 비밀번호 재설정에서만 호출되고
 * `signup()`에서는 호출되지 않아, 신규 가입자가 한 글자 비밀번호를 설정할 수 있었습니다.
 *
 * 검사 순서도 함께 고정합니다. 비밀번호 검사는 이메일 인증 상태를 확인하기 전에 수행되어야
 * 단순 입력 오류로 인증 결과가 소모되지 않습니다.
 */
@ExtendWith(MockitoExtension.class)
class MemberSignupPasswordPolicyTest {

    @Mock private MemberRepository memberRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private EmailService emailService;

    private MemberSignupService signupService;

    @BeforeEach
    void setUp() {
        // 인증 상태는 실제 구현을 그대로 씁니다. 이 테스트들이 검증하는 것이 그 동작이기 때문입니다.
        signupService = new MemberSignupService(
                memberRepository, passwordEncoder, emailService, new MemberVerificationService());
    }

    @Test
    void 정책에_미달하는_비밀번호로는_가입할_수_없다() {
        assertThatThrownBy(() -> signupService.signup("2305001", "1", "학생", null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("비밀번호는");
    }

    @Test
    void 영문_숫자_특수문자를_모두_포함하지_않으면_거부된다() {
        assertThatThrownBy(() -> signupService.signup("2305001", "password1234", "학생", null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("비밀번호는");

        assertThatThrownBy(() -> signupService.signup("2305001", "Password!!!!", "학생", null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("비밀번호는");
    }

    @Test
    void 비밀번호_검사는_이메일_인증_확인보다_먼저_수행된다() {
        // 인증 증표가 없는 요청이므로, 비밀번호 검사가 나중이라면 "이메일 인증" 오류가 나와야 합니다.
        assertThatThrownBy(() -> signupService.signup("2305001", "1", "학생", null))
                .hasMessageContaining("비밀번호는");

        // 인증 상태를 조회하기 전에 차단되므로 저장소를 건드리지 않습니다.
        verifyNoInteractions(memberRepository);
    }

    @Test
    void 정책을_만족하는_비밀번호는_정책_검사를_통과하고_인증_단계로_넘어간다() {
        assertThatThrownBy(() -> signupService.signup("2305001", "Strong1234!", "학생", null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("이메일 인증");
    }

    @Test
    void 증표_없이는_비밀번호가_정책을_만족해도_가입할_수_없다() {
        // 인증 증표는 인증을 통과한 주체만 가질 수 있습니다. 증표가 없으면 저장소를 건드리기 전에 막힙니다.
        assertThatThrownBy(() -> signupService.signup("2305001", "Strong1234!", "학생", null))
                .isInstanceOf(IllegalArgumentException.class);

        verifyNoInteractions(memberRepository);
    }
}
