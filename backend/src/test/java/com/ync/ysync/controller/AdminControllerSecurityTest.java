package com.ync.ysync.controller;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.RequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 💡 관리자 API의 권한 경계를 고정하는 회귀 테스트입니다.
 *
 * `AdminController`는 게시글·댓글 삭제와 복구, 신고 기각, 권한 승인처럼 되돌리기 어려운 작업을
 * 모아두고 있는데 테스트가 하나도 없었습니다. `@PreAuthorize`는 어노테이션 한 줄이라 지우거나
 * 범위를 넓히기 쉽고, 그런 변경은 컴파일 오류도 테스트 실패도 내지 않습니다.
 *
 * 특히 승인·반려는 SUPER_ADMIN 전용인데 ADMIN에게 열리면, 승인받은 ADMIN이 다른 사용자를
 * 스스로 ADMIN으로 만들 수 있게 됩니다.
 */
@SpringBootTest
@Transactional
class AdminControllerSecurityTest {

    private static final long ABSENT_ID = 999_999L;

    @Autowired WebApplicationContext context;
    @Autowired MemberRepository members;

    // 컨텍스트 로딩이 실제 메일 발송 설정에 의존하지 않도록 대체합니다.
    @MockitoBean JavaMailSender mailSender;

    private MockMvc mvc() {
        return MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
    }

    private UsernamePasswordAuthenticationToken authOf(MemberRole role) {
        Member member = members.save(Member.builder()
                .loginId(role.name().toLowerCase() + "-" + System.nanoTime())
                .password("encoded").name("테스트")
                .role(role).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(true).isSuspended(false)
                .build());
        return new UsernamePasswordAuthenticationToken(member.getLoginId(), "",
                List.of(new SimpleGrantedAuthority("ROLE_" + role.name())));
    }

    private int statusOf(RequestBuilder request) throws Exception {
        return mvc().perform(request).andReturn().getResponse().getStatus();
    }

    // ---------- 비로그인 차단 ----------

    @ParameterizedTest(name = "비로그인은 {0} {1}에 접근할 수 없다")
    @CsvSource({
            "GET,    /api/v1/admin/requests",
            "GET,    /api/v1/admin/reports",
            "POST,   /api/v1/admin/requests/1/approve",
            "POST,   /api/v1/admin/requests/1/reject",
            "POST,   /api/v1/admin/posts/1/restore",
            "POST,   /api/v1/admin/reports/dismiss",
    })
    void 관리자_API는_비로그인_접근을_막는다(String method, String path) throws Exception {
        RequestBuilder request = switch (method) {
            case "GET" -> get(path);
            default -> post(path).contentType(MediaType.APPLICATION_JSON).content("{}");
        };

        mvc().perform(request).andExpect(status().isUnauthorized());
    }

    @Test
    void 삭제_API도_비로그인_접근을_막는다() throws Exception {
        mvc().perform(delete("/api/v1/admin/posts/1")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"테스트\"}"))
                .andExpect(status().isUnauthorized());

        mvc().perform(delete("/api/v1/admin/comments/1")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"테스트\"}"))
                .andExpect(status().isUnauthorized());
    }

    // ---------- 일반 사용자 차단 ----------

    @Test
    void 일반_사용자는_관리자_기능에_접근할_수_없다() throws Exception {
        var user = authOf(MemberRole.USER);

        assertThat(statusOf(get("/api/v1/admin/requests").with(authentication(user)))).isEqualTo(403);
        assertThat(statusOf(get("/api/v1/admin/reports").with(authentication(user)))).isEqualTo(403);
        assertThat(statusOf(delete("/api/v1/admin/posts/1")
                .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"사유\"}")
                .with(authentication(user)))).isEqualTo(403);
        assertThat(statusOf(post("/api/v1/admin/reports/dismiss")
                .contentType(MediaType.APPLICATION_JSON).content("{\"targetType\":\"POST\",\"targetId\":1}")
                .with(authentication(user)))).isEqualTo(403);
    }

    // ---------- ADMIN과 SUPER_ADMIN의 경계 ----------

    @Test
    void 권한_승인과_반려는_SUPER_ADMIN만_할_수_있다() throws Exception {
        // ADMIN에게 열리면 승인받은 ADMIN이 다른 사용자를 스스로 ADMIN으로 만들 수 있습니다.
        var admin = authOf(MemberRole.ADMIN);

        assertThat(statusOf(post("/api/v1/admin/requests/" + ABSENT_ID + "/approve")
                .with(authentication(admin)))).isEqualTo(403);
        assertThat(statusOf(post("/api/v1/admin/requests/" + ABSENT_ID + "/reject")
                .with(authentication(admin)))).isEqualTo(403);
        assertThat(statusOf(get("/api/v1/admin/requests").with(authentication(admin)))).isEqualTo(403);
    }

    @Test
    void SUPER_ADMIN은_승인_대기_목록을_조회할_수_있다() throws Exception {
        mvc().perform(get("/api/v1/admin/requests")
                        .with(authentication(authOf(MemberRole.SUPER_ADMIN))))
                .andExpect(status().isOk());
    }

    @Test
    void 신고_목록은_ADMIN과_SUPER_ADMIN_모두_조회할_수_있다() throws Exception {
        for (MemberRole role : List.of(MemberRole.ADMIN, MemberRole.SUPER_ADMIN)) {
            mvc().perform(get("/api/v1/admin/reports").with(authentication(authOf(role))))
                    .andExpect(status().isOk());
        }
    }

    // ---------- 권한을 통과한 뒤의 입력 검증 ----------

    @Test
    void 댓글_삭제는_사유를_요구한다() throws Exception {
        // 삭제 주체와 사유는 사용자에게 노출되므로 빈 사유로 지워지면 안 됩니다.
        var admin = authOf(MemberRole.ADMIN);

        assertThat(statusOf(delete("/api/v1/admin/comments/" + ABSENT_ID)
                .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"   \"}")
                .with(authentication(admin)))).isEqualTo(400);
    }

    @Test
    void 신고_기각은_알_수_없는_대상_타입을_거부한다() throws Exception {
        var admin = authOf(MemberRole.ADMIN);

        assertThat(statusOf(post("/api/v1/admin/reports/dismiss")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"targetType\":\"UNKNOWN\",\"targetId\":1}")
                .with(authentication(admin)))).isEqualTo(400);
    }

    @Test
    void 없는_대상을_삭제하거나_복구하면_404를_돌려준다() throws Exception {
        var admin = authOf(MemberRole.ADMIN);

        assertThat(statusOf(delete("/api/v1/admin/posts/" + ABSENT_ID)
                .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"사유\"}")
                .with(authentication(admin)))).isEqualTo(404);
        assertThat(statusOf(post("/api/v1/admin/posts/" + ABSENT_ID + "/restore")
                .with(authentication(admin)))).isEqualTo(404);
        assertThat(statusOf(delete("/api/v1/admin/comments/" + ABSENT_ID)
                .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"사유\"}")
                .with(authentication(admin)))).isEqualTo(404);
    }
}
