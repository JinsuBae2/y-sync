package com.ync.ysync.service;

import com.ync.ysync.controller.FeedbackController;
import com.ync.ysync.domain.Feedback;
import com.ync.ysync.repository.FeedbackRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Transactional
class FeedbackIntegrationTest {
    @Autowired FeedbackService service;
    @Autowired FeedbackRepository repository;
    @Autowired FeedbackController controller;
    @Autowired WebApplicationContext context;
    @Autowired MemberRepository members;
    @MockitoBean JavaMailSender mailSender;

    @Test
    void httpSubmissionRequiresLoginAndOrdinaryUsersCannotBrowse() throws Exception {
        var mvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
        mvc.perform(multipart("/api/v1/feedback").param("category", "BUG")
                .param("title", "오류").param("content", "재현 내용"))
                .andExpect(status().isUnauthorized());
        var member = members.save(Member.builder().loginId("feedback-http-user").password("encoded")
                .name("테스트").role(MemberRole.USER).isActivated(true).build());
        var auth = new UsernamePasswordAuthenticationToken(member.getLoginId(), "",
                List.of(new SimpleGrantedAuthority("ROLE_USER")));
        mvc.perform(multipart("/api/v1/feedback").param("category", "SUGGESTION")
                .param("title", "기능 제안").param("content", "제안 내용").with(authentication(auth)))
                .andExpect(status().isCreated());
        mvc.perform(get("/api/v1/admin/feedback").with(authentication(auth)))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/admin/feedback/images/1").with(authentication(auth)))
                .andExpect(status().isForbidden());
        mvc.perform(put("/api/v1/admin/feedback/1/reviewed").with(authentication(auth)))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void submitsPrivateImagesAndFiltersReviewedFeedback() throws Exception {
        byte[] png = new byte[]{(byte) 0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10};
        service.submit(1L, Feedback.Category.BUG, "  시간표 오류  ", "재현 내용", "시간표", "Web/PWA",
                List.of(new MockMultipartFile("images", "test.png", "image/png", png)));
        var page = controller.list(false, 0);
        var item = page.getContent().getFirst();
        assertEquals("시간표 오류", item.title());
        assertEquals(1, item.imageIds().size());
        var image = controller.image(item.imageIds().getFirst());
        assertArrayEquals(png, image.getBody());
        assertEquals("no-store", image.getHeaders().getCacheControl());
        controller.review(item.id());
        assertEquals(0, controller.list(false, 0).getTotalElements());
        assertTrue(controller.list(true, 0).getContent().getFirst().reviewed());
    }

    @Test
    @WithMockUser(roles = "USER")
    void ordinaryUserCannotReadFeedbackImagesOrReview() {
        assertThrows(AccessDeniedException.class, () -> controller.list(null, 0));
        assertThrows(AccessDeniedException.class, () -> controller.image(1L));
        assertThrows(AccessDeniedException.class, () -> controller.review(1L));
    }

    @Test
    void rejectsInvalidTextAndAttachmentsWithoutSaving() {
        long before = repository.count();
        assertThrows(IllegalArgumentException.class, () -> service.submit(1L, Feedback.Category.BUG,
                " ", "내용", "", "", List.of()));
        assertThrows(IllegalArgumentException.class, () -> service.submit(1L, Feedback.Category.BUG,
                "제목", "x".repeat(3001), "", "", List.of()));
        var fake = new MockMultipartFile("images", "fake.png", "image/png", "<script>bad</script>".getBytes());
        assertThrows(IllegalArgumentException.class, () -> service.submit(1L, Feedback.Category.BUG,
                "제목", "내용", "", "", List.of(fake)));
        assertThrows(IllegalArgumentException.class, () -> service.submit(1L, Feedback.Category.BUG,
                "제목", "내용", "", "", List.of(fake, fake, fake, fake)));
        var large = new MockMultipartFile("images", "large.png", "image/png", new byte[2 * 1024 * 1024 + 1]);
        assertThrows(IllegalArgumentException.class, () -> service.submit(1L, Feedback.Category.BUG,
                "제목", "내용", "", "", List.of(large)));
        assertEquals(before, repository.count());
    }
}
