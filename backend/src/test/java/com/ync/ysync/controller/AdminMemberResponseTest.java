package com.ync.ysync.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AdminMemberResponseTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void 회원관리_DTO는_민감정보를_직렬화하지_않는다() throws Exception {
        Member member = sensitiveMember();

        String json = objectMapper.writeValueAsString(AdminMemberResponse.from(member));

        assertThat(json)
                .contains("\"loginId\":\"2305001\"")
                .doesNotContain("password", "fcmToken", "socialId", "authVersion", "secret-value");
    }

    @Test
    void Member_직접_직렬화에서도_password는_차단된다() throws Exception {
        String json = objectMapper.writeValueAsString(sensitiveMember());

        assertThat(json).doesNotContain("password", "encoded-secret");
    }

    private Member sensitiveMember() {
        Member member = Member.builder()
                .loginId("2305001")
                .password("encoded-secret")
                .name("학생")
                .role(MemberRole.USER)
                .provider(AuthProvider.KAKAO)
                .socialId("secret-value")
                .authType(AuthType.PASSWORD)
                .isActivated(true)
                .build();
        member.setFcmToken("secret-value");
        member.setAuthVersion(9);
        return member;
    }
}
