package com.ync.ysync.controller;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.service.MemberService;
import io.swagger.v3.oas.annotations.Operation;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/v1/admin/members")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')") // 💡 학과 관리자 이상 권한만 호출 가능
public class AdminMemberController {

    private final MemberService memberService;

    @GetMapping
    @Operation(summary = "회원 목록 조회", description = "학과 회원 목록을 페이징 및 이름/학번 검색으로 조회합니다.")
    public ResponseEntity<Page<AdminMemberResponse>> getMembers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "15") int size,
            @RequestParam(required = false) String search) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<AdminMemberResponse> members = memberService.getMembers(pageRequest, search)
                .map(AdminMemberResponse::from);
        return ResponseEntity.ok(members);
    }

    @PostMapping
    @Operation(summary = "학생 단건 사전등록", description = "관리자가 학생의 학번, 이름, 권한을 입력하여 사전에 등록시킵니다. (미활성 상태)")
    public ResponseEntity<?> createMember(@RequestBody AdminCreateMemberRequest request, Authentication authentication) {
        if (request.getLoginId() == null || request.getName() == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "학번과 이름을 모두 입력해 주세요."));
        }
        try {
            Member member = memberService.createMemberByAdmin(
                    request.getLoginId(), request.getName(), request.getRole(), currentRole(authentication));
            return ResponseEntity.ok(AdminMemberResponse.from(member));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/csv")
    @Operation(summary = "학생 CSV 대량 일괄 등록", description = "학번,이름,역할이 적힌 CSV 파일을 업로드하여 학생들을 일괄 등록합니다.")
    public ResponseEntity<?> uploadCsv(@RequestParam("file") MultipartFile file, Authentication authentication) {
        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "파일이 비어있습니다."));
        }
        try {
            memberService.createMembersByCsv(file.getInputStream(), currentRole(authentication));
            return ResponseEntity.ok(Map.of("message", "CSV 일괄 사전 등록이 완료되었습니다."));
        } catch (Exception e) {
            log.error("CSV 일괄 사전 등록 실패", e);
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    @Operation(summary = "학생 정보 수정", description = "학생의 이름 및 권한을 수정합니다.")
    public ResponseEntity<?> updateMember(@PathVariable Long id, @RequestBody AdminUpdateMemberRequest request,
            Authentication authentication) {
        try {
            Member member = memberService.updateMemberByAdmin(
                    id, request.getName(), request.getRole(), currentRole(authentication));
            return ResponseEntity.ok(AdminMemberResponse.from(member));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "학생 삭제", description = "특정 학생 정보를 완전히 삭제합니다.")
    public ResponseEntity<?> deleteMember(@PathVariable Long id) {
        try {
            memberService.deleteMemberByAdmin(id);
            return ResponseEntity.ok(Map.of("message", "회원이 성공적으로 삭제되었습니다."));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/{id}/password-reset-email")
    @Operation(summary = "비밀번호 재설정 안내 발송", description = "회원의 등록 이메일로 비밀번호 재설정 인증번호를 전송합니다. 계정 데이터와 권한은 변경하지 않습니다.")
    public ResponseEntity<?> sendPasswordResetEmail(@PathVariable Long id) {
        try {
            memberService.requestPasswordResetByAdmin(id);
            return ResponseEntity.ok(Map.of("message", "등록된 이메일로 비밀번호 재설정 안내를 발송했습니다."));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/{id}/reset-registration")
    @Operation(summary = "계정 재등록 초기화", description = "이메일과 비밀번호를 초기화하고 가입 대기 상태로 전환합니다. 게시글, 댓글, 권한과 정지 상태는 유지합니다.")
    public ResponseEntity<?> resetRegistration(@PathVariable Long id) {
        try {
            memberService.resetMemberRegistration(id);
            return ResponseEntity.ok(Map.of("message", "계정이 재등록 대기 상태로 초기화되었습니다."));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @Deprecated
    @PostMapping("/{id}/reset-password")
    @Operation(summary = "계정 재등록 초기화(구형 호환)", description = "구형 관리자 클라이언트 호환용입니다. reset-registration을 사용해 주세요.", deprecated = true)
    public ResponseEntity<?> resetPasswordCompatibility(@PathVariable Long id) {
        return resetRegistration(id);
    }

    @PostMapping("/{id}/suspend")
    @Operation(summary = "회원 차단", description = "특정 회원을 차단(정지) 상태로 설정합니다.")
    public ResponseEntity<?> suspendMember(@PathVariable Long id) {
        try {
            memberService.suspendMember(id);
            return ResponseEntity.ok(Map.of("message", "회원이 성공적으로 차단되었습니다."));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/{id}/unsuspend")
    @Operation(summary = "회원 차단 해제", description = "특정 회원의 차단(정지) 상태를 해제합니다.")
    public ResponseEntity<?> unsuspendMember(@PathVariable Long id) {
        try {
            memberService.unsuspendMember(id);
            return ResponseEntity.ok(Map.of("message", "회원의 차단이 성공적으로 해제되었습니다."));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @Data
    public static class AdminCreateMemberRequest {
        private String loginId;
        private String name;
        private MemberRole role;
    }

    @Data
    public static class AdminUpdateMemberRequest {
        private String name;
        private MemberRole role;
    }

    private MemberRole currentRole(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .map(authority -> authority.getAuthority().replaceFirst("^ROLE_", ""))
                .map(MemberRole::valueOf)
                .max(Enum::compareTo)
                .orElseThrow(() -> new IllegalArgumentException("관리자 권한을 확인할 수 없습니다."));
    }
}
