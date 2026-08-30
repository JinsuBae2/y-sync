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
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MemberAccountRecoveryTest {

    @Mock
    private MemberRepository memberRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private EmailService emailService;

    private MemberService memberService;

    @BeforeEach
    void setUp() {
        memberService = new MemberService(memberRepository, passwordEncoder, emailService);
    }

    @Test
    void 비밀번호_재설정은_계정과_권한을_유지하고_인증버전을_올린다() {
        Member member = activeMember();
        member.setAuthVersion(2);
        member.setFcmToken("existing-token");
        when(memberRepository.findByLoginId("2305009")).thenReturn(Optional.of(member));
        when(passwordEncoder.encode("NewPassword1!")).thenReturn("encoded-new-password");

        memberService.requestPasswordReset("2305009", "배진수");
        ArgumentCaptor<String> codeCaptor = ArgumentCaptor.forClass(String.class);
        verify(emailService).sendPasswordResetCode(org.mockito.ArgumentMatchers.eq("2305009@ync.ac.kr"),
                codeCaptor.capture());

        memberService.confirmPasswordReset("2305009", codeCaptor.getValue(), "NewPassword1!");

        assertThat(member.getPassword()).isEqualTo("encoded-new-password");
        assertThat(member.getEmail()).isEqualTo("2305009@ync.ac.kr");
        assertThat(member.getRole()).isEqualTo(MemberRole.ADMIN);
        assertThat(member.isActivated()).isTrue();
        assertThat(member.getAuthVersion()).isEqualTo(3);
        assertThat(member.getFcmToken()).isNull();
    }

    @Test
    void 재등록_초기화는_활동데이터와_권한_정지상태를_보존한다() {
        Member member = activeMember();
        member.setSuspended(true);
        member.setAuthVersion(4);
        member.setFcmToken("existing-token");
        when(memberRepository.findById(1L)).thenReturn(Optional.of(member));
        when(passwordEncoder.encode(anyString())).thenReturn("encoded-temp-password");

        memberService.resetMemberRegistration(1L);

        assertThat(member.getPassword()).isEqualTo("encoded-temp-password");
        assertThat(member.getEmail()).isNull();
        assertThat(member.getRole()).isEqualTo(MemberRole.ADMIN);
        assertThat(member.isSuspended()).isTrue();
        assertThat(member.isActivated()).isFalse();
        assertThat(member.getAuthVersion()).isEqualTo(5);
        assertThat(member.getFcmToken()).isNull();
    }

    private Member activeMember() {
        Member member = Member.builder()
                .loginId("2305009")
                .password("encoded-old-password")
                .name("배진수")
                .role(MemberRole.ADMIN)
                .provider(AuthProvider.LOCAL)
                .authType(AuthType.PASSWORD)
                .isActivated(true)
                .build();
        member.setEmail("2305009@ync.ac.kr");
        return member;
    }
}
