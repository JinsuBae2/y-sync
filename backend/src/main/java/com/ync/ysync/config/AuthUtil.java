package com.ync.ysync.config;

import com.ync.ysync.domain.Member;
import com.ync.ysync.repository.MemberRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.Optional;

@Component
public class AuthUtil {
    
    private final MemberRepository memberRepository;
    
    public AuthUtil(MemberRepository memberRepository) {
        this.memberRepository = memberRepository;
    }
    
    public Long getLoginMemberId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || auth.getPrincipal().equals("anonymousUser")) {
            return null;
        }
        String loginId = (String) auth.getPrincipal();
        Optional<Member> member = memberRepository.findByLoginId(loginId);
        return member.map(Member::getId).orElse(null);
    }

    public String getLoginMemberRole() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || auth.getPrincipal().equals("anonymousUser")) {
            return null;
        }
        return auth.getAuthorities().iterator().next().getAuthority().replace("ROLE_", "");
    }
}
