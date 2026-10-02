package com.ync.ysync.config;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 💡 공지 API의 비로그인 공개 범위를 고정하는 회귀 테스트입니다.
 *
 * 이전 설정은 `GET /api/v1/notices/**`를 통째로 공개해 `/api/v1/notices/{id}/comments`까지
 * 비로그인 접근이 가능했습니다. 댓글 응답에는 작성자 실명과 회원 ID가 포함되므로
 * 토큰 없이 학생 개인정보를 수집할 수 있는 상태였습니다.
 *
 * 공개 범위를 넓히는 변경이 다시 들어오면 이 테스트가 실패해야 합니다.
 */
@SpringBootTest
@Transactional
class NoticePublicAccessSecurityTest {

    @Autowired WebApplicationContext context;
    @Autowired MemberRepository members;

    // 컨텍스트 로딩 시 실제 메일 발송 설정에 의존하지 않도록 대체합니다.
    @MockitoBean JavaMailSender mailSender;

    private static final long ABSENT_NOTICE_ID = 999_999L;

    private MockMvc mvc() {
        return MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
    }

    @Test
    void 공지_목록과_검색은_비로그인으로_조회된다() throws Exception {
        mvc().perform(get("/api/v1/notices"))
                .andExpect(status().isOk());

        mvc().perform(get("/api/v1/notices/search").param("keyword", "공지"))
                .andExpect(status().isOk());
    }

    @Test
    void 공지_상세는_비로그인_접근이_차단되지_않는다() throws Exception {
        // 존재하지 않는 공지라 4xx가 날 수 있으나, 인증 경계에서 막히면 안 됩니다.
        int status = mvc().perform(get("/api/v1/notices/" + ABSENT_NOTICE_ID))
                .andReturn().getResponse().getStatus();

        assertThat(status).isNotEqualTo(401);
    }

    @Test
    void 공지_댓글은_비로그인_조회가_차단된다() throws Exception {
        mvc().perform(get("/api/v1/notices/" + ABSENT_NOTICE_ID + "/comments"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void 공지_댓글은_로그인_사용자에게는_계속_제공된다() throws Exception {
        Member member = members.save(Member.builder()
                .loginId("notice-comment-reader")
                .password("encoded-password")
                .name("테스트학생")
                .role(MemberRole.USER)
                .isActivated(true)
                .build());
        var auth = new UsernamePasswordAuthenticationToken(member.getLoginId(), "",
                List.of(new SimpleGrantedAuthority("ROLE_USER")));

        int status = mvc().perform(get("/api/v1/notices/" + ABSENT_NOTICE_ID + "/comments")
                        .with(authentication(auth)))
                .andReturn().getResponse().getStatus();

        assertThat(status).isNotEqualTo(401);
    }
}
