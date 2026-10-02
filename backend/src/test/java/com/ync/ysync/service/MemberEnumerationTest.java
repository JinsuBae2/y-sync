package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.catchThrowable;
import static org.mockito.Mockito.when;

/**
 * 💡 가입 흐름이 계정 상태를 구분해 알려주지 않도록 고정하는 회귀 테스트입니다.
 *
 * 타인 명의 가입의 표적은 '명단에 있지만 아직 가입하지 않은 학번'입니다. 응답이 '명단에 없음'과
 * '이름 불일치'를 구분하면, 학번을 순서대로 넣어보는 것만으로 표적 명단을 만들 수 있습니다.
 *
 * 이미 가입된 경우는 구분해 알려줍니다. 정상 사용자를 로그인으로 안내해야 하고, 공격자가 찾는
 * 것은 미가입 상태라 이 정보만으로는 표적을 좁힐 수 없기 때문입니다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class MemberEnumerationTest {

    private static final String REGISTERED_ID = "2305001";
    private static final String UNKNOWN_ID = "9999999";
    private static final String ACTIVATED_ID = "2305002";

    @Mock private MemberRepository memberRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private EmailService emailService;

    private MemberSignupService signupService;

    @BeforeEach
    void setUp() {
        // 인증 상태는 실제 구현을 그대로 씁니다. 이 테스트들이 검증하는 것이 그 동작이기 때문입니다.
        signupService = new MemberSignupService(
                memberRepository, passwordEncoder, emailService, new MemberVerificationService());
        when(memberRepository.findByLoginId(UNKNOWN_ID)).thenReturn(Optional.empty());
        when(memberRepository.findByLoginId(REGISTERED_ID)).thenReturn(Optional.of(member("홍길동", false)));
        when(memberRepository.findByLoginId(ACTIVATED_ID)).thenReturn(Optional.of(member("김철수", true)));
    }

    private Member member(String name, boolean activated) {
        return Member.builder()
                .loginId(REGISTERED_ID).password("TEMP").name(name)
                .role(MemberRole.USER).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(activated).isSuspended(false)
                .build();
    }

    @Test
    void 등록되지_않은_학번과_이름_불일치는_같은_응답을_준다() {
        // 두 응답이 다르면 어떤 학번이 명단에 있는지 조회할 수 있게 됩니다.
        Throwable unknown = catchThrowable(
                () -> signupService.verifyStudentForSignup(UNKNOWN_ID, "홍길동"));
        Throwable wrongName = catchThrowable(
                () -> signupService.verifyStudentForSignup(REGISTERED_ID, "다른이름"));

        assertThat(unknown).isInstanceOf(IllegalArgumentException.class);
        assertThat(wrongName).isInstanceOf(IllegalArgumentException.class);
        assertThat(unknown.getMessage()).isEqualTo(wrongName.getMessage());
    }

    @Test
    void 어떤_실패_조합이든_같은_문구를_준다() {
        // 문구에 "등록되지 않은 경우 문의하세요" 같은 안내가 들어가는 것 자체는 문제가 아닙니다.
        // 중요한 것은 어떤 입력으로 실패해도 응답이 구분되지 않는다는 점입니다.
        java.util.List<String> messages = java.util.stream.Stream.of(
                        catchThrowable(() -> signupService.verifyStudentForSignup(UNKNOWN_ID, "홍길동")),
                        catchThrowable(() -> signupService.verifyStudentForSignup(UNKNOWN_ID, "아무개")),
                        catchThrowable(() -> signupService.verifyStudentForSignup(REGISTERED_ID, "다른이름")))
                .map(Throwable::getMessage)
                .distinct()
                .toList();

        assertThat(messages).hasSize(1);
    }

    @Test
    void 정상_조합은_통과한다() {
        // 응답을 통일해도 실제 가입자는 막히지 않아야 합니다.
        signupService.verifyStudentForSignup(REGISTERED_ID, "홍길동");
    }

    @Test
    void 이미_가입한_학번은_로그인으로_안내한다() {
        // 이 경우만 구분합니다. 공격자가 찾는 미가입 상태를 알려주지는 않습니다.
        assertThatThrownBy(() -> signupService.verifyStudentForSignup(ACTIVATED_ID, "김철수"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("로그인");
    }

    @Test
    void 비밀번호_재설정도_계정_상태를_구분하지_않는다() {
        // 기존에 지켜지던 성질입니다. 가입 흐름을 고치면서 깨지지 않았는지 함께 고정합니다.
        Throwable unknown = catchThrowable(
                () -> signupService.requestPasswordReset(UNKNOWN_ID, "홍길동"));
        Throwable notActivated = catchThrowable(
                () -> signupService.requestPasswordReset(REGISTERED_ID, "홍길동"));

        assertThat(unknown.getMessage()).isEqualTo(notActivated.getMessage());
    }
}
