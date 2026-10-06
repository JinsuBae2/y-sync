package com.ync.ysync.config;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class DemoAccountInitializer implements CommandLineRunner {
    private final MemberRepository members;
    private final PasswordEncoder passwords;
    private final boolean enabled;
    private final String loginId;
    private final String password;

    public DemoAccountInitializer(MemberRepository members, PasswordEncoder passwords,
            @Value("${ysync.demo.enabled:false}") boolean enabled,
            @Value("${ysync.demo.login-id:}") String loginId,
            @Value("${ysync.demo.password:}") String password) {
        this.members = members;
        this.passwords = passwords;
        this.enabled = enabled;
        this.loginId = loginId;
        this.password = password;
    }

    @Override
    @Transactional
    public void run(String... args) {
        if (!enabled) return;
        if (loginId.isBlank() || !loginId.equals(loginId.trim()) || password.isBlank()) {
            throw new IllegalStateException("데모 아이디와 비밀번호 설정이 필요합니다.");
        }
        // 개발 시드가 나중에 실행되어 공개 계정을 일반/관리자 권한으로 덮어쓰지 못하게 합니다.
        if (java.util.Set.of("2305009", "2300001", "2300002", "2505034").contains(loginId)) {
            throw new IllegalStateException("개발 시드 아이디는 데모 계정으로 사용할 수 없습니다.");
        }
        Member existing = members.findByLoginId(loginId).orElse(null);
        if (existing != null) {
            if (existing.getRole() != MemberRole.DEMO) {
                throw new IllegalStateException("데모 아이디가 기존 회원과 충돌합니다.");
            }
            return;
        }
        Member demo = Member.builder().loginId(loginId).password(passwords.encode(password))
                .name("임시").role(MemberRole.DEMO).isActivated(true).build();
        demo.setNoticeEnabled(false);
        demo.setCommentEnabled(false);
        members.save(demo);
    }
}
