package com.ync.ysync.controller;

import com.ync.ysync.repository.MemberRepository;
import jakarta.servlet.http.HttpSession;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/members")
@RequiredArgsConstructor
public class MemberProfileController {

    private final MemberRepository memberRepository;

    @GetMapping("/me")
    public ResponseEntity<MemberResponse> getMyProfile(HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) {
            // Spring Security가 401을 처리하겠지만, 
            // 세션이 풀린 상태에서 컨트롤러에 도달했다면 직접 401 반환
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        return memberRepository.findById(memberId)
                .map(member -> ResponseEntity.ok(new MemberResponse(member.getId(), member.getLoginId(), member.getName(), member.getRole().name())))
                .orElse(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
    }

    @Data
    @AllArgsConstructor
    public static class MemberResponse {
        private Long id; // 💡 회원의 PK ID를 추가합니다 (삭제 권한 체크용)
        private String loginId;
        private String name;
        private String role;
    }
}
