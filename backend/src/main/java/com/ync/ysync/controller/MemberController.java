package com.ync.ysync.controller;

import com.ync.ysync.domain.Member;
import com.ync.ysync.service.MemberService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.security.web.context.SecurityContextRepository;

@Slf4j
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class MemberController {

    private final MemberService memberService;
    private final SecurityContextRepository securityContextRepository = new HttpSessionSecurityContextRepository();

    @PostMapping("/signup")
    public ResponseEntity<String> signup(@RequestBody SignupRequest request) {
        memberService.signup(request.getLoginId(), request.getPassword(), request.getName());
        return ResponseEntity.ok("회원가입 성공");
    }

    @PostMapping("/login")
    public ResponseEntity<String> login(@RequestBody LoginRequest request, HttpServletRequest httpRequest,
            HttpServletResponse httpResponse) {
        Member member = memberService.login(request.getLoginId(), request.getPassword());

        // 1. Spring Security 6 방식: 명시적으로 SecurityContext를 생성하고 Repository를 통해 세션에 저장
        SecurityContext sc = SecurityContextHolder.createEmptyContext();
        sc.setAuthentication(
                new UsernamePasswordAuthenticationToken(member.getLoginId(), null,
                        java.util.Collections
                                .singletonList(new org.springframework.security.core.authority.SimpleGrantedAuthority(
                                        "ROLE_" + member.getRole().name()))));
        SecurityContextHolder.setContext(sc);
        securityContextRepository.saveContext(sc, httpRequest, httpResponse);

        // 2. 세션 로깅 및 부가 정보 저장
        HttpSession session = httpRequest.getSession(false);
        if (session != null) {
            session.setAttribute("loginMemberId", member.getId());
            session.setAttribute("loginMemberRole", member.getRole().name());
            log.info("로그인 성공! 세션 생성 보장 완료 - SessionID: {}, LoginID: {}", session.getId(), member.getLoginId());
        } else {
            log.error("로그인 에러 - 세션이 정상적으로 생성되지 않았습니다.");
        }

        return ResponseEntity.ok("로그인 성공");
    }

    @PostMapping("/logout")
    public ResponseEntity<String> logout(HttpServletRequest request, HttpServletResponse response) {
        SecurityContextHolder.clearContext();

        HttpSession session = request.getSession(false);
        if (session != null) {
            log.info("로그아웃 성공! 세션 만료 처리됨 - SessionID: {}", session.getId());
            session.invalidate();
        } else {
            log.info("로그아웃 요청을 받았으나 이미 세션이 없는 상태입니다.");
        }

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
