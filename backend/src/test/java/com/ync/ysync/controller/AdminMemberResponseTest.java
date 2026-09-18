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
    void 회원관리_DTO는_도용_추적에_필요한_인증_메일을_포함한다() throws Exception {
        // 학교 메일은 사용자 정의 ID라 학번에서 유도할 수 없습니다. 타인 학번으로 가입한 사례를
        // 사후에 특정하려면 관리자가 가입에 쓰인 메일 주소를 볼 수 있어야 합니다.
        Member member = sensitiveMember();
        member.setEmail("hong@ync.ac.kr");

        String json = objectMapper.writeValueAsString(AdminMemberResponse.from(member));

        assertThat(json).contains("\"email\":\"hong@ync.ac.kr\"");
    }

    @Test
    void 회원관리_DTO는_관리에_쓰지_않는_개인_알림_설정을_노출하지_않는다() throws Exception {
        String json = objectMapper.writeValueAsString(AdminMemberResponse.from(sensitiveMember()));

        assertThat(json).doesNotContain("noticeEnabled", "commentEnabled");
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
