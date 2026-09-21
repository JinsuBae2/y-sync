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
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 💡 가입 인증 증표를 고정하는 회귀 테스트입니다.
 *
 * 이전 구현은 인증 통과 기록을 학번만을 키로 저장하고 가입 요청에서 증표를 요구하지 않았습니다.
 * 그래서 어떤 학생이 인증을 마친 뒤 유효 시간(10분) 안에, 학번과 이름만 아는 제3자가 가입을
 * 완료해 계정을 가져갈 수 있었습니다. 공격자에게 학교 메일함이 없어도 성립했습니다.
 *
 * 이제 인증을 통과한 주체에게만 증표를 돌려주고, 가입은 그 증표를 제시해야 하며, 소비는
 * 원자적이라 같은 증표로 두 번 성공할 수 없습니다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class MemberSignupGrantTest {

    private static final String LOGIN_ID = "2305001";
    private static final String NAME = "학생";
    private static final String EMAIL = "student@ync.ac.kr";
    private static final String PASSWORD = "Strong1234!";

    @Mock private MemberRepository memberRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private EmailService emailService;

    @Mock
    private MemberWithdrawer memberWithdrawer;

    private MemberService memberService;

    @BeforeEach
    void setUp() {
        memberService = new MemberService(memberRepository, passwordEncoder, emailService, memberWithdrawer);
        when(memberRepository.findByLoginId(LOGIN_ID)).thenReturn(Optional.of(pendingMember()));
        when(memberRepository.findByEmail(anyString())).thenReturn(Optional.empty());
        when(passwordEncoder.encode(anyString())).thenReturn("encoded");
        when(memberRepository.save(org.mockito.ArgumentMatchers.any(Member.class)))
                .thenAnswer(call -> call.getArgument(0));
    }

    private Member pendingMember() {
        return Member.builder()
                .loginId(LOGIN_ID).password("TEMP_PENDING").name(NAME)
                .role(MemberRole.USER).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(false).isSuspended(false)
                .build();
    }

    /** 인증까지 마치고 증표를 받아 옵니다. */
    private String verifyAndGetGrant() {
        memberService.sendVerificationEmail(LOGIN_ID, NAME, EMAIL);
        ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
        verify(emailService, org.mockito.Mockito.atLeastOnce())
                .sendVerificationCode(eq(EMAIL), captor.capture());
        return memberService.verifySignupCode(LOGIN_ID, captor.getValue());
    }

    @Test
    void 인증을_통과하면_추측할_수_없는_증표를_돌려준다() {
        String grant = verifyAndGetGrant();

        assertThat(grant).isNotBlank();
        // 256비트 난수를 URL 안전 형식으로 인코딩하므로 충분히 길어야 합니다.
        assertThat(grant.length()).isGreaterThanOrEqualTo(40);
        assertThat(grant).matches("[A-Za-z0-9_-]+");
    }

    @Test
    void 매번_다른_증표가_발급된다() {
        // 재발급 쿨다운은 학번 단위로 걸리므로 서로 다른 학번으로 발급합니다.
        List<String> grants = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            String loginId = "23050" + (10 + i);
            String email = "student" + i + "@ync.ac.kr";
            when(memberRepository.findByLoginId(loginId)).thenReturn(Optional.of(pendingMember()));

            memberService.sendVerificationEmail(loginId, NAME, email);
            ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
            verify(emailService).sendVerificationCode(eq(email), captor.capture());
            grants.add(memberService.verifySignupCode(loginId, captor.getValue()));
        }

        assertThat(grants).doesNotHaveDuplicates();
        assertThat(grants).allMatch(grant -> grant != null && !grant.isBlank());
    }

    @Test
    void 증표를_제시하면_가입이_완료된다() {
        String grant = verifyAndGetGrant();

        Member joined = memberService.signup(LOGIN_ID, PASSWORD, NAME, grant);

        assertThat(joined.isActivated()).isTrue();
        assertThat(joined.getEmail()).isEqualTo(EMAIL);
    }

    @Test
    void 증표가_없으면_인증을_마쳤어도_가입할_수_없다() {
        // 이것이 이전 구현에서 뚫려 있던 경로입니다. 제3자는 학번과 이름만 알고 증표는 받지 못합니다.
        verifyAndGetGrant();

        assertThatThrownBy(() -> memberService.signup(LOGIN_ID, PASSWORD, NAME, null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 남의_인증을_추측한_증표로는_가입할_수_없다() {
        verifyAndGetGrant();

        assertThatThrownBy(() -> memberService.signup(LOGIN_ID, PASSWORD, NAME, "guessed-grant-value"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 틀린_증표는_정상_사용자의_인증_결과를_지우지_않는다() {
        // 제3자가 아무 값이나 보내서 진짜 사용자의 가입을 방해할 수 없어야 합니다.
        String grant = verifyAndGetGrant();

        assertThatThrownBy(() -> memberService.signup(LOGIN_ID, PASSWORD, NAME, "wrong"))
                .isInstanceOf(IllegalArgumentException.class);

        assertThat(memberService.signup(LOGIN_ID, PASSWORD, NAME, grant).isActivated()).isTrue();
    }

    @Test
    void 같은_증표로_두_번_가입할_수_없다() {
        String grant = verifyAndGetGrant();
        memberService.signup(LOGIN_ID, PASSWORD, NAME, grant);

        assertThatThrownBy(() -> memberService.signup(LOGIN_ID, PASSWORD, NAME, grant))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 동시에_같은_증표로_들어와도_한_번만_성공한다() throws Exception {
        String grant = verifyAndGetGrant();

        int threads = 8;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CyclicBarrier barrier = new CyclicBarrier(threads);
        AtomicInteger succeeded = new AtomicInteger();

        try {
            List<Future<?>> futures = new ArrayList<>();
            for (int i = 0; i < threads; i++) {
                futures.add(pool.submit(() -> {
                    try {
                        barrier.await(5, TimeUnit.SECONDS);
                        memberService.signup(LOGIN_ID, PASSWORD, NAME, grant);
                        succeeded.incrementAndGet();
                    } catch (IllegalArgumentException expected) {
                        // 증표는 최대 한 번만 소비됩니다.
                    } catch (Exception e) {
                        throw new IllegalStateException(e);
                    }
                }));
            }
            for (Future<?> future : futures) {
                future.get(10, TimeUnit.SECONDS);
            }
        } finally {
            pool.shutdownNow();
        }

        assertThat(succeeded.get()).isEqualTo(1);
    }
}
