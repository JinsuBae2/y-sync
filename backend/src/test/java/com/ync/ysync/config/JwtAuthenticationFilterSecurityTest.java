package com.ync.ysync.config;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class JwtAuthenticationFilterSecurityTest {

    private static final String SECRET = "test-secret-key-test-secret-key-test-secret-key-test-secret-key";

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void 역할변경_전_JWT는_authVersion_불일치로_거부된다() throws Exception {
        JwtUtil jwtUtil = new JwtUtil(SECRET, 3_600_000);
        String oldToken = jwtUtil.generateToken("2305001", "USER", 2);
        Member member = member(MemberRole.ADMIN, 3);
        MemberRepository repository = mock(MemberRepository.class);
        when(repository.findByLoginId("2305001")).thenReturn(Optional.of(member));
        JwtAuthenticationFilter filter = new JwtAuthenticationFilter(jwtUtil, repository);
        MockHttpServletRequest request = requestWith(oldToken);
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicBoolean continued = new AtomicBoolean(false);

        filter.doFilterInternal(request, response, (req, res) -> continued.set(true));

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(continued).isFalse();
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
    }

    @Test
    void JWT의_역할_claim이_아니라_DB의_현재_역할을_사용한다() throws Exception {
        JwtUtil jwtUtil = new JwtUtil(SECRET, 3_600_000);
        String tokenWithStaleRole = jwtUtil.generateToken("2305001", "ADMIN", 4);
        Member member = member(MemberRole.USER, 4);
        MemberRepository repository = mock(MemberRepository.class);
        when(repository.findByLoginId("2305001")).thenReturn(Optional.of(member));
        JwtAuthenticationFilter filter = new JwtAuthenticationFilter(jwtUtil, repository);

        filter.doFilterInternal(requestWith(tokenWithStaleRole), new MockHttpServletResponse(), (req, res) -> { });

        assertThat(SecurityContextHolder.getContext().getAuthentication().getAuthorities())
                .extracting("authority")
                .containsExactly("ROLE_USER");
    }

    private MockHttpServletRequest requestWith(String token) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("Authorization", "Bearer " + token);
        return request;
    }

    private Member member(MemberRole role, int authVersion) {
        Member member = Member.builder()
                .loginId("2305001")
                .password("encoded-password")
                .name("학생")
                .role(role)
                .provider(AuthProvider.LOCAL)
                .authType(AuthType.PASSWORD)
                .isActivated(true)
                .build();
        member.setAuthVersion(authVersion);
        return member;
    }
}
