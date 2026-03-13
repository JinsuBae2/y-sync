package com.ync.ysync.controller;

import com.ync.ysync.domain.Member;
import com.ync.ysync.service.MemberService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpSession;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class MemberController {

    private final MemberService memberService;

    @PostMapping("/signup")
    public ResponseEntity<String> signup(@RequestBody SignupRequest request) {
        memberService.signup(request.getLoginId(), request.getPassword(), request.getName());
        return ResponseEntity.ok("회원가입 성공");
    }

    @PostMapping("/login")
    public ResponseEntity<String> login(@RequestBody LoginRequest request, jakarta.servlet.http.HttpServletRequest httpRequest) {
        Member member = memberService.login(request.getLoginId(), request.getPassword());
        
        jakarta.servlet.http.HttpSession session = httpRequest.getSession(true);
        session.setAttribute("loginMemberId", member.getId());
        session.setAttribute("loginMemberRole", member.getRole().name());
        
        org.springframework.security.core.context.SecurityContext sc = org.springframework.security.core.context.SecurityContextHolder.getContext();
        sc.setAuthentication(new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(member.getLoginId(), null, java.util.Collections.emptyList()));
        session.setAttribute(org.springframework.security.web.context.HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY, sc);
        
        return ResponseEntity.ok("로그인 성공");
    }

    @PostMapping("/logout")
    public ResponseEntity<String> logout(HttpSession session) {
        session.invalidate();
        return ResponseEntity.ok("로그아웃 성공");
    }

    @Data
    public static class SignupRequest {
        private String loginId;
        private String password;
        private String name;
    }

    @Data
    public static class LoginRequest {
        private String loginId;
        private String password;
    }
}
