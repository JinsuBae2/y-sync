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

    @GetMapping("/check-duplicate")
    @Operation(summary = "아이디 중복 확인", description = "입력한 아이디(학번)가 이미 등록되어 있는지 확인합니다.")
    public ResponseEntity<Map<String, Boolean>> checkDuplicate(@RequestParam String loginId) {
        boolean isDuplicate = memberRepository.findByLoginId(loginId).isPresent();
        log.info("아이디 중복 확인 요청 - LoginID: {}, 중복여부: {}", loginId, isDuplicate);
        return ResponseEntity.ok(Map.of("isDuplicate", isDuplicate));
    }

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

    @PostMapping("/verify-student/send-code")
    @Operation(summary = "이메일 인증 코드 전송", description = "학번을 입력받아 [학번]@ync.ac.kr로 6자리 인증 메일을 전송합니다.")
    public ResponseEntity<?> sendVerificationCode(@RequestBody Map<String, String> request) {
        String loginId = request.get("loginId");
        if (loginId == null || loginId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "학번을 입력해 주세요."));
        }
        try {
            memberService.sendVerificationEmail(loginId);
            return ResponseEntity.ok(Map.of("message", "인증 코드가 이메일로 전송되었습니다."));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            log.error("인증 이메일 발송 실패", e);
            return ResponseEntity.internalServerError().body(Map.of("message", "이메일 발송 중 오류가 발생했습니다."));
        }
    }

    @PostMapping("/verify-student/verify-code")
    @Operation(summary = "이메일 인증 코드 검증", description = "이메일로 수신된 6자리 인증 코드를 확인합니다.")
    public ResponseEntity<?> verifyCode(@RequestBody Map<String, String> request) {
        String loginId = request.get("loginId");
        String code = request.get("code");
        if (loginId == null || code == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "학번과 인증 코드를 모두 입력해 주세요."));
        }
        try {
            boolean isSuccess = memberService.verifyCode(loginId, code);
            return ResponseEntity.ok(Map.of("success", isSuccess, "message", "인증이 성공적으로 완료되었습니다."));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/social-login")
    @Operation(summary = "소셜 로그인 (비활성화)", description = "이메일 인증 가입 도입으로 인해 비활성화된 API입니다.")
    public ResponseEntity<?> socialLogin(@RequestBody SocialLoginRequest request) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(Map.of("message", "소셜 로그인 기능은 비활성화되었습니다. 학번 로그인을 이용해 주세요."));
    }

    @PostMapping("/social-signup")
    @Operation(summary = "소셜 회원가입 (비활성화)", description = "이메일 인증 가입 도입으로 인해 비활성화된 API입니다.")
    public ResponseEntity<?> socialSignup(@RequestBody SocialSignupRequest request) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(Map.of("message", "소셜 회원가입 기능은 비활성화되었습니다. 학번 로그인을 이용해 주세요."));
    }

    @PostMapping("/logout")
    public ResponseEntity<String> logout() {
        String loginId = SecurityContextHolder.getContext().getAuthentication().getName();
        if (loginId != null && !loginId.equals("anonymousUser")) {
            Optional<Member> memberOpt = memberRepository.findByLoginId(loginId);
            if (memberOpt.isPresent()) {
                Member member = memberOpt.get();
                member.setFcmToken(null); // 💡 로그아웃 시 FCM 토큰 클리어
                memberRepository.save(member);
                log.info("로그아웃 처리 - DB 내 FCM 토큰 삭제 완료: {}", loginId);
            }
        }
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
