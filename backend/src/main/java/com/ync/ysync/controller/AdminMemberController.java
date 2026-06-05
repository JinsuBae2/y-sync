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
    public ResponseEntity<Page<Member>> getMembers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "15") int size,
            @RequestParam(required = false) String search) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Member> members = memberService.getMembers(pageRequest, search);
        return ResponseEntity.ok(members);
    }

    @PostMapping
    @Operation(summary = "학생 단건 사전등록", description = "관리자가 학생의 학번, 이름, 권한을 입력하여 사전에 등록시킵니다. (미활성 상태)")
    public ResponseEntity<?> createMember(@RequestBody AdminCreateMemberRequest request) {
        if (request.getLoginId() == null || request.getName() == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "학번과 이름을 모두 입력해 주세요."));
        }
        try {
            Member member = memberService.createMemberByAdmin(request.getLoginId(), request.getName(), request.getRole());
            return ResponseEntity.ok(member);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/csv")
    @Operation(summary = "학생 CSV 대량 일괄 등록", description = "학번,이름,역할이 적힌 CSV 파일을 업로드하여 학생들을 일괄 등록합니다.")
    public ResponseEntity<?> uploadCsv(@RequestParam("file") MultipartFile file) {
        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "파일이 비어있습니다."));
        }
        try {
            memberService.createMembersByCsv(file.getInputStream());
            return ResponseEntity.ok(Map.of("message", "CSV 일괄 사전 등록이 완료되었습니다."));
        } catch (Exception e) {
            log.error("CSV 일괄 사전 등록 실패", e);
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    @Operation(summary = "학생 정보 수정", description = "학생의 이름 및 권한을 수정합니다.")
    public ResponseEntity<?> updateMember(@PathVariable Long id, @RequestBody AdminUpdateMemberRequest request) {
        try {
            Member member = memberService.updateMemberByAdmin(id, request.getName(), request.getRole());
            return ResponseEntity.ok(member);
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

    @PostMapping("/{id}/reset-password")
    @Operation(summary = "회원 비밀번호 초기화 및 비활성화", description = "특정 회원의 비밀번호를 초기화하고 활성화 상태를 가입 대기(false) 상태로 리셋합니다.")
    public ResponseEntity<?> resetPassword(@PathVariable Long id) {
        try {
            memberService.resetMemberPassword(id);
            return ResponseEntity.ok(Map.of("message", "비밀번호 초기화 및 계정 리셋이 완료되었습니다."));
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
}
