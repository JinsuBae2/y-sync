package com.ync.ysync.config;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import java.util.List;
import static org.assertj.core.api.Assertions.*;

class DemoAccessPolicyTest {
    @Test void allowsOnlyReviewedReadsAndLogout() {
        for (String method : new String[]{"GET", "HEAD"}) {
            for (String path : new String[]{"/api/v1/notices", "/api/v1/notices/feed", "/api/v1/notices/feed-updates",
                    "/api/v1/notices/search", "/api/v1/notices/1", "/api/v1/notices/1/comments",
                    "/api/v1/community/search", "/api/v1/members/me/posts", "/api/v1/members/me/comments",
                    "/uploads/sample.png", "/s3-uploads/sample.pdf"}) {
                assertThat(DemoAccessPolicy.isAllowed(method, path)).as(method + " " + path).isTrue();
            }
        }
        assertThat(DemoAccessPolicy.isAllowed("POST", "/api/v1/auth/logout")).isTrue();
        for (String method : new String[]{"POST", "PUT", "PATCH", "DELETE"}) {
            assertThat(DemoAccessPolicy.isAllowed(method, "/api/v1/notices")).isFalse();
        }
        for (String path : new String[]{"/api/v1/admin/members", "/api/v1/admin/feedback/images/1",
                "/api/v1/future", "/api/v1/notices/1/new-feature", "/api/v1/auth/fcm-token"}) {
            assertThat(DemoAccessPolicy.isAllowed("GET", path)).isFalse();
        }
    }

    @Test void disabledDemoRejectsExistingSessionsEvenOnPublicReads() throws Exception {
        var auth = new UsernamePasswordAuthenticationToken("demo", null,
                List.of(new SimpleGrantedAuthority("ROLE_DEMO")));
        SecurityContextHolder.getContext().setAuthentication(auth);
        try {
            var request = new MockHttpServletRequest("GET", "/api/v1/notices");
            var response = new MockHttpServletResponse();
            new DemoReadOnlyFilter(false).doFilter(request, response, (req, res) -> fail("disabled demo reached controller"));
            assertThat(response.getStatus()).isEqualTo(403);
        } finally {
            SecurityContextHolder.clearContext();
        }
    }
}
