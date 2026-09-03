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
import org.springframework.security.crypto.password.PasswordEncoder;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MemberAdminSecurityTest {

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
    void admin은_superAdmin_계정을_생성할_수_없다() {
        assertThatThrownBy(() -> memberService.createMemberByAdmin(
                "2305001", "관리대상", MemberRole.SUPER_ADMIN, MemberRole.ADMIN))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("SUPER_ADMIN");

        verify(memberRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void admin은_자신이나_다른_회원을_superAdmin으로_승격할_수_없다() {
        Member target = member(MemberRole.ADMIN);
        when(memberRepository.findById(1L)).thenReturn(Optional.of(target));

        assertThatThrownBy(() -> memberService.updateMemberByAdmin(
                1L, null, MemberRole.SUPER_ADMIN, MemberRole.ADMIN))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("SUPER_ADMIN");

        assertThat(target.getRole()).isEqualTo(MemberRole.ADMIN);
        assertThat(target.getAuthVersion()).isZero();
        verify(memberRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void admin은_CSV로도_superAdmin을_생성할_수_없다() {
        ByteArrayInputStream csv = new ByteArrayInputStream(
                "loginId,name,role\n2305001,관리대상,SUPER_ADMIN\n".getBytes(StandardCharsets.UTF_8));

        assertThatThrownBy(() -> memberService.createMembersByCsv(csv, MemberRole.ADMIN))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("SUPER_ADMIN");

        verify(memberRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void 역할이_변경되면_authVersion이_증가한다() {
        Member target = member(MemberRole.USER);
        target.setAuthVersion(7);
        when(memberRepository.findById(1L)).thenReturn(Optional.of(target));
        when(memberRepository.save(target)).thenReturn(target);

        memberService.updateMemberByAdmin(1L, null, MemberRole.ADMIN, MemberRole.ADMIN);

        assertThat(target.getRole()).isEqualTo(MemberRole.ADMIN);
        assertThat(target.getAuthVersion()).isEqualTo(8);
    }

    private Member member(MemberRole role) {
        return Member.builder()
                .loginId("2305001")
                .password("encoded-password")
                .name("관리대상")
                .role(role)
                .provider(AuthProvider.LOCAL)
                .authType(AuthType.PASSWORD)
                .isActivated(true)
                .build();
    }
}
