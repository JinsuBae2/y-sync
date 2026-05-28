package com.ync.ysync.controller;

import com.ync.ysync.config.JwtUtil;
import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.Member;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.service.MemberService;
import com.ync.ysync.service.SocialAuthService;
import io.swagger.v3.oas.annotations.Operation;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class MemberController {

    private final MemberService memberService;
    private final SocialAuthService socialAuthService;
    private final JwtUtil jwtUtil;
    private final MemberRepository memberRepository;

    @PostMapping("/signup")
    public ResponseEntity<String> signup(@RequestBody SignupRequest request) {
        memberService.signup(request.getLoginId(), request.getPassword(), request.getName());
        return ResponseEntity.ok("회원가입 성공");
    }

    @PostMapping("/login")
    public ResponseEntity<Map<String, String>> login(@RequestBody LoginRequest request) {
        Member member = memberService.login(request.getLoginId(), request.getPassword());
        String token = jwtUtil.generateToken(member.getLoginId(), member.getRole().name());
        log.info("로컬 로그인 성공 - LoginID: {}", member.getLoginId());
        return ResponseEntity.ok(Map.of("token", token, "message", "로그인 성공"));
    }

    @PostMapping("/social-login")
    @Operation(summary = "소셜 로그인", description = "구글 또는 카카오의 AccessToken을 검증하고, 가입된 회원이면 JWT를 발급하며, 미가입 시 202 상태코드와 임시 식별자를 반환합니다.")
    public ResponseEntity<?> socialLogin(@RequestBody SocialLoginRequest request) {
        String socialId = socialAuthService.getSocialId(request.getAccessToken(), request.getProvider());
        Member member = memberService.socialLogin(socialId, request.getProvider());

        if (member != null) {
            String token = jwtUtil.generateToken(member.getLoginId(), member.getRole().name());
            log.info("소셜 로그인 성공 - Provider: {}, SocialID: {}", request.getProvider(), socialId);
            return ResponseEntity.ok(Map.of("token", token, "message", "로그인 성공"));
        } else {
            log.info("소셜 로그인 미가입자 발견 - Provider: {}, SocialID: {}", request.getProvider(), socialId);
            return ResponseEntity.status(HttpStatus.ACCEPTED)
                    .body(Map.of("socialId", socialId, "provider", request.getProvider().name(), "message", "가입되지 않은 소셜 계정입니다. 학번을 입력하여 가입을 진행해주세요."));
        }
    }

    @PostMapping("/social-signup")
    @Operation(summary = "소셜 회원가입", description = "소셜 로그인 후 반환된 socialId와 provider, 그리고 추가 정보(학번, 이름)를 이용해 회원가입을 완료하고 JWT를 발급합니다.")
    public ResponseEntity<?> socialSignup(@RequestBody SocialSignupRequest request) {
        try {
            Member member = memberService.socialSignup(request.getLoginId(), request.getName(), request.getSocialId(), request.getProvider(), request.getPassword());
            String token = jwtUtil.generateToken(member.getLoginId(), member.getRole().name());
            log.info("소셜 회원가입 성공 - LoginID: {}, Provider: {}", member.getLoginId(), request.getProvider());
            return ResponseEntity.ok(Map.of("token", token, "message", "소셜 회원가입 성공"));
        } catch (IllegalArgumentException e) {
            if ("REQUIRE_PASSWORD".equals(e.getMessage())) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", "REQUIRE_PASSWORD"));
            }
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/logout")
    public ResponseEntity<String> logout() {
        SecurityContextHolder.clearContext();
        return ResponseEntity.ok("로그아웃 성공");
    }

    @Operation(summary = "기기 FCM 토큰 발급/수정", description = "프론트엔드에서 발급받은 푸시 알림용 디바이스 토큰(FCM)을 서버에 저장합니다.")
    @PostMapping("/fcm-token")
    public ResponseEntity<String> updateFcmToken(@RequestBody FCMTokenRequest request) {
        String loginId = SecurityContextHolder.getContext().getAuthentication().getName();
        if (loginId == null || loginId.equals("anonymousUser")) {
            return ResponseEntity.status(401).body("로그인이 필요합니다.");
        }
        
        Optional<Member> memberOpt = memberRepository.findByLoginId(loginId);
        if (memberOpt.isPresent()) {
            memberService.updateFcmToken(memberOpt.get().getId(), request.getFcmToken());
            log.info("FCM 토큰 업데이트 완료 - LoginID: {}", loginId);
            return ResponseEntity.ok("FCM 토큰이 저장되었습니다.");
        }
        return ResponseEntity.status(404).body("회원 정보를 찾을 수 없습니다.");
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

    @Data
    public static class SocialLoginRequest {
        private String accessToken;
        private AuthProvider provider;
    }

    @Data
    public static class SocialSignupRequest {
        private String loginId;
        private String name;
        private String socialId;
        private AuthProvider provider;
        private String password;
    }
}
