package com.ync.ysync.controller;

import com.ync.ysync.domain.AdminRequest;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.AdminRequestRepository;
import com.ync.ysync.repository.MemberRepository;
import jakarta.servlet.http.HttpSession;
import lombok.AllArgsConstructor;
import lombok.Builder; // 💡 추가
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminRequestRepository adminRequestRepository;
    private final MemberRepository memberRepository;

    // 💡 관리자 권한 신청 (일반 유저용)
    @PostMapping("/requests")
    public ResponseEntity<?> requestAdmin(@RequestBody AdminRequestDto.Create requestDto, HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        // 중복 신청 확인 (PENDING 상태가 있으면 추가 신청 불가)
        boolean hasPending = adminRequestRepository.findTopByRequesterIdOrderByRequestedAtDesc(memberId)
                .map(req -> req.getStatus() == AdminRequest.RequestStatus.PENDING)
                .orElse(false);
        
        if (hasPending) return ResponseEntity.badRequest().body("이미 대기 중인 신청 건이 있습니다.");

        Member requester = memberRepository.findById(memberId).orElseThrow();
        AdminRequest adminRequest = AdminRequest.builder()
                .requester(requester)
                .reason(requestDto.getReason())
                .build();

        adminRequestRepository.save(adminRequest);
        return ResponseEntity.ok("관리자 권한 신청이 완료되었습니다.");
    }

    // 💡 승인 대기 목록 조회 (SUPER_ADMIN 전용)
    @GetMapping("/requests")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<List<AdminRequestDto.Response>> getPendingRequests() {
        List<AdminRequestDto.Response> responses = adminRequestRepository.findAllByStatusOrderByRequestedAtDesc(AdminRequest.RequestStatus.PENDING).stream()
                .map(AdminRequestDto.Response::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    // 💡 신청 승인 (SUPER_ADMIN 전용)
    @PostMapping("/requests/{id}/approve")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> approveRequest(@PathVariable Long id) {
        AdminRequest adminRequest = adminRequestRepository.findById(id).orElseThrow();
        if (adminRequest.getStatus() != AdminRequest.RequestStatus.PENDING) {
            return ResponseEntity.badRequest().body("이미 처리된 신청 건입니다.");
        }

        adminRequest.approve();
        Member requester = adminRequest.getRequester();
        requester.setRole(MemberRole.ADMIN); // 💡 역할 변경
        
        adminRequestRepository.save(adminRequest);
        memberRepository.save(requester);
        
        return ResponseEntity.ok(requester.getName() + " 유저가 ADMIN으로 승인되었습니다.");
    }

    // 💡 신청 거절 (SUPER_ADMIN 전용)
    @PostMapping("/requests/{id}/reject")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> rejectRequest(@PathVariable Long id) {
        AdminRequest adminRequest = adminRequestRepository.findById(id).orElseThrow();
        if (adminRequest.getStatus() != AdminRequest.RequestStatus.PENDING) {
            return ResponseEntity.badRequest().body("이미 처리된 신청 건입니다.");
        }

        adminRequest.reject();
        adminRequestRepository.save(adminRequest);
        
        return ResponseEntity.ok("신청이 거절되었습니다.");
    }

    // 💡 통계 및 DTO 클래스들
    public static class AdminRequestDto {
        
        @Data
        @NoArgsConstructor
        @AllArgsConstructor
        public static class Create {
            private String reason;
        }

        @Data
        @Builder
        @NoArgsConstructor
        @AllArgsConstructor
        public static class Response {
            private Long id;
            private String requesterName;
            private String loginId;
            private String reason;
            private String status;
            private String requestedAt;

            public static Response from(AdminRequest request) {
                return Response.builder()
                        .id(request.getId())
                        .requesterName(request.getRequester().getName())
                        .loginId(request.getRequester().getLoginId())
                        .reason(request.getReason())
                        .status(request.getStatus().name())
                        .requestedAt(request.getRequestedAt().toString())
                        .build();
            }
        }
    }
}
