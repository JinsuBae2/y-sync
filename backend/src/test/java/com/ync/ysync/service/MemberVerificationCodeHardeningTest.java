package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 💡 이메일 인증번호의 시도 제한·원자성·재발급 간격을 고정하는 회귀 테스트입니다.
 *
 * 이전 구현은 (1) 코드 불일치 시 challenge를 폐기하지 않아 6자리(10^6)를 5분간 무제한
 * 대입할 수 있었고, (2) `get → 검증 → remove` 구조라 같은 코드로 동시에 들어온 두 요청이
 * 모두 통과할 수 있었습니다.
 *
 * 계정 잠금은 의도적으로 구현하지 않습니다. 학번 기준 잠금은 공격자가 타인 학번으로 일부러
 * 실패시켜 그 계정을 잠그는 DoS 수단이 되므로, 실패의 책임을 계정이 아니라 challenge에 지웁니다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class MemberVerificationCodeHardeningTest {

    private static final String LOGIN_ID = "2305001";
    private static final String NAME = "학생";
    private static final String EMAIL = "student@ync.ac.kr";

    @Mock private MemberRepository memberRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private EmailService emailService;

    private MemberService memberService;

    @BeforeEach
    void setUp() {
        memberService = new MemberService(memberRepository, passwordEncoder, emailService);
        when(memberRepository.findByLoginId(LOGIN_ID)).thenReturn(Optional.of(pendingMember()));
        when(memberRepository.findByEmail(anyString())).thenReturn(Optional.empty());
    }

    @Test
    void 인증번호를_5회_틀리면_정상_코드로도_인증할_수_없다() {
        String code = issueSignupCodeAndCapture();

        for (int i = 1; i <= 4; i++) {
            assertThatThrownBy(() -> memberService.verifySignupCode(LOGIN_ID, "000000"))
                    .hasMessageContaining("인증 번호가 일치하지 않습니다");
        }

        // 5번째 실패에서 challenge가 폐기됩니다.
        assertThatThrownBy(() -> memberService.verifySignupCode(LOGIN_ID, "000000"))
                .hasMessageContaining("시도 횟수를 초과");

        // 폐기되었으므로 올바른 코드도 더 이상 통하지 않습니다.
        assertThatThrownBy(() -> memberService.verifySignupCode(LOGIN_ID, code))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 정상_인증에_사용된_인증번호는_재사용할_수_없다() {
        String code = issueSignupCodeAndCapture();

        assertThat(memberService.verifySignupCode(LOGIN_ID, code)).isNotBlank();

        assertThatThrownBy(() -> memberService.verifySignupCode(LOGIN_ID, code))
                .hasMessageContaining("인증 요청 기록이 없거나 만료되었습니다");
    }

    @Test
    void 재발급은_쿨다운_동안_거부된다() {
        issueSignupCodeAndCapture();

        assertThatThrownBy(() -> memberService.sendVerificationEmail(LOGIN_ID, NAME, EMAIL))
                .hasMessageContaining("잠시 후에 다시 요청");
    }

    @Test
    void 시도_횟수를_소진해도_다른_학번의_인증에는_영향이_없다() {
        // 계정 잠금을 두지 않았음을 확인합니다. 폐기 대상은 challenge이지 계정이 아닙니다.
        String code = issueSignupCodeAndCapture();
        for (int i = 1; i <= 5; i++) {
            assertThatThrownBy(() -> memberService.verifySignupCode(LOGIN_ID, "000000"))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        String otherLoginId = "2305002";
        when(memberRepository.findByLoginId(otherLoginId)).thenReturn(Optional.of(pendingMember()));
        memberService.sendVerificationEmail(otherLoginId, NAME, "other@ync.ac.kr");
        ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
        verify(emailService).sendVerificationCode(eq("other@ync.ac.kr"), captor.capture());

        assertThat(memberService.verifySignupCode(otherLoginId, captor.getValue())).isNotBlank();
        assertThat(code).isNotNull();
    }

    @Test
    void 동일한_인증번호로_동시에_검증해도_최대_1건만_성공한다() throws Exception {
        String code = issueSignupCodeAndCapture();

        int threadCount = 2;
        CyclicBarrier barrier = new CyclicBarrier(threadCount);
        AtomicInteger successes = new AtomicInteger();
        ExecutorService pool = Executors.newFixedThreadPool(threadCount);
        List<Future<?>> futures = new ArrayList<>();

        for (int i = 0; i < threadCount; i++) {
            futures.add(pool.submit(() -> {
                barrier.await();
                try {
                    memberService.verifySignupCode(LOGIN_ID, code);
                    successes.incrementAndGet();
                } catch (IllegalArgumentException expectedForLoser) {
                    // 한 요청만 challenge를 소비합니다.
                }
                return null;
            }));
        }
        for (Future<?> future : futures) {
            future.get();
        }
        pool.shutdown();

        assertThat(successes.get()).isEqualTo(1);
    }

    private String issueSignupCodeAndCapture() {
        memberService.sendVerificationEmail(LOGIN_ID, NAME, EMAIL);
        ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
        verify(emailService).sendVerificationCode(eq(EMAIL), captor.capture());
        return captor.getValue();
    }

    private Member pendingMember() {
        return Member.builder()
                .loginId(LOGIN_ID)
                .password("encoded-password")
                .name(NAME)
                .role(MemberRole.USER)
                .provider(AuthProvider.LOCAL)
                .authType(AuthType.PASSWORD)
                .isActivated(false)
                .build();
    }
}
