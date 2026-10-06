package com.ync.ysync.config;

import com.ync.ysync.domain.*;
import com.ync.ysync.repository.*;
import com.ync.ysync.service.MemberSignupService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.security.crypto.password.PasswordEncoder;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.assertj.core.api.Assertions.*;

@SpringBootTest(properties = {"ysync.demo.enabled=true", "ysync.demo.login-id=demo-test", "ysync.demo.password=Demo-test-123!"})
@Transactional
class DemoAccessIntegrationTest {
    @Autowired WebApplicationContext context;
    @Autowired MemberRepository members;
    @Autowired NoticeRepository notices;
    @Autowired CommunityPostRepository posts;
    @Autowired PasswordEncoder passwords;
    @Autowired JwtUtil jwt;
    @Autowired MemberSignupService signup;
    @MockitoBean JavaMailSender mail;
    MockMvc mvc;
    Member demo;
    String bearer;

    @BeforeEach void setup() {
        mvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
        demo = members.findByLoginId("demo-test").orElseThrow();
        bearer = "Bearer " + jwt.generateToken(demo.getLoginId(), demo.getRole().name(), demo.getAuthVersion());
    }

    @Test void loginAndOrdinaryReadsWorkWithoutAdministratorAccess() throws Exception {
        mvc.perform(post("/api/v1/auth/login").contentType("application/json")
                .content("{\"loginId\":\"demo-test\",\"password\":\"Demo-test-123!\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.token").isString());
        for (String path : new String[]{"/members/me", "/members/settings", "/community", "/notices",
                "/calendar", "/timetable/personal", "/timetable/GRADE_1", "/notifications", "/scraps"}) {
            mvc.perform(get("/api/v1" + path).param("startDate", "2026-10-01").param("endDate", "2026-10-31").header("Authorization", bearer)).andExpect(status().isOk());
        }
        mvc.perform(get("/api/v1/members/me").header("Authorization", bearer))
                .andExpect(jsonPath("$.role").value("DEMO"))
                .andExpect(jsonPath("$.gradeConfirmationRequired").value(false));
        mvc.perform(get("/api/v1/admin/members").header("Authorization", bearer)).andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/future-feature").header("Authorization", bearer)).andExpect(status().isForbidden());
    }

    @Test void allWritesAreRejectedBeforeControllersIncludingPublicAuthRoutes() throws Exception {
        for (String path : new String[]{"/members/settings", "/notifications/read", "/timetable/personal/1"}) {
            mvc.perform(put("/api/v1" + path).header("Authorization", bearer).contentType("application/json").content("{}"))
                    .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("DEMO_READ_ONLY"));
        }
        for (String path : new String[]{"/scraps", "/reports", "/auth/fcm-token", "/auth/password-reset/request", "/new-feature"}) {
            mvc.perform(post("/api/v1" + path).header("Authorization", bearer).contentType("application/json").content("{}"))
                    .andExpect(status().isForbidden());
        }
        mvc.perform(multipart("/api/v1/community").header("Authorization", bearer)).andExpect(status().isForbidden());
        mvc.perform(delete("/api/v1/community/1").header("Authorization", bearer)).andExpect(status().isForbidden());
        mvc.perform(patch("/api/v1/members/me").header("Authorization", bearer)).andExpect(status().isForbidden());
    }

    @Test void readsAndLogoutDoNotChangeDataOrOtherSessions() throws Exception {
        Notice notice = notices.save(new Notice("데모 공지", "내용", demo, NoticeType.NOTICE, null, Grade.ALL, false, null, null));
        CommunityPost post = posts.save(CommunityPost.builder().title("데모 게시글").content("내용").member(demo).category("FREE").build());
        demo.setFcmToken("unchanged-token");
        members.saveAndFlush(demo);
        long noticeViews = notice.getViewCount();
        long postViews = post.getViewCount();
        mvc.perform(get("/api/v1/notices/" + notice.getId()).header("Authorization", bearer)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/community/" + post.getId()).header("Authorization", bearer)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/community/" + post.getId() + "/comments").header("Authorization", bearer)).andExpect(status().isOk());
        mvc.perform(post("/api/v1/auth/logout").header("Authorization", bearer)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/members/me").header("Authorization", bearer)).andExpect(status().isOk());
        assertThat(notices.findById(notice.getId()).orElseThrow().getViewCount()).isEqualTo(noticeViews);
        assertThat(posts.findById(post.getId()).orElseThrow().getViewCount()).isEqualTo(postViews);
        assertThat(members.findById(demo.getId()).orElseThrow().getFcmToken()).isEqualTo("unchanged-token");
    }

    @Test void anonymousAccountRecoveryCannotModifyDemo() throws Exception {
        String before = demo.getPassword();
        assertThatThrownBy(() -> signup.requestPasswordReset(demo.getLoginId(), demo.getName()))
                .isInstanceOf(IllegalArgumentException.class).hasMessage("등록된 계정 정보를 확인할 수 없습니다.");
        assertThatThrownBy(() -> signup.confirmPasswordReset(demo.getLoginId(), "000000", "New-password-123!"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThat(members.findById(demo.getId()).orElseThrow().getPassword()).isEqualTo(before);
    }
    @Test void initializerCreatesOnlyOnceAndNeverOverwritesOrdinaryMembers() {
        long before = members.count();
        var initializer = new DemoAccountInitializer(members, passwords, true, "new-demo-fixture", "Fixture-123!");
        initializer.run();
        Member created = members.findByLoginId("new-demo-fixture").orElseThrow();
        assertThat(created.getRole()).isEqualTo(MemberRole.DEMO);
        assertThat(created.getName()).isEqualTo("임시");
        assertThat(created.isActivated()).isTrue();
        assertThat(passwords.matches("Fixture-123!", created.getPassword())).isTrue();
        assertThat(created.isNoticeEnabled()).isFalse();
        String encoded = created.getPassword();
        initializer.run();
        assertThat(members.count()).isEqualTo(before + 1);
        assertThat(members.findById(created.getId()).orElseThrow().getPassword()).isEqualTo(encoded);
        new DemoAccountInitializer(members, passwords, false, "disabled-demo", "").run();
        assertThat(members.findByLoginId("disabled-demo")).isEmpty();
        assertThatThrownBy(() -> new DemoAccountInitializer(members, passwords, true, "", "").run())
                .isInstanceOf(IllegalStateException.class);
        Member ordinary = members.save(Member.builder().loginId("ordinary-fixture").password(encoded)
                .name("일반 회원").role(MemberRole.USER).isActivated(true).build());
        assertThatThrownBy(() -> new DemoAccountInitializer(members, passwords, true, ordinary.getLoginId(), "Other-123!").run())
                .isInstanceOf(IllegalStateException.class);
        assertThat(ordinary.getRole()).isEqualTo(MemberRole.USER);
        assertThat(ordinary.getPassword()).isEqualTo(encoded);
    }

    @Test void ordinaryMemberStillCanChangeSettings() throws Exception {
        Member ordinary = members.save(Member.builder().loginId("ordinary-writer").password("encoded")
                .name("일반 회원").role(MemberRole.USER).isActivated(true).build());
        String token = "Bearer " + jwt.generateToken(ordinary.getLoginId(), "USER", ordinary.getAuthVersion());
        mvc.perform(put("/api/v1/members/settings").header("Authorization", token)
                .contentType("application/json").content("{\"noticeEnabled\":false,\"commentEnabled\":false}"))
                .andExpect(status().isOk());
        assertThat(members.findById(ordinary.getId()).orElseThrow().isNoticeEnabled()).isFalse();
    }

    @Test void disabledDemoCannotLoginWithValidCredentials() {
        var disabledService = new com.ync.ysync.service.MemberService(members, passwords);
        assertThatThrownBy(() -> disabledService.login(demo.getLoginId(), "Demo-test-123!"))
                .isInstanceOf(IllegalArgumentException.class).hasMessage("아이디 또는 비밀번호가 맞지 않습니다.");
    }

}
