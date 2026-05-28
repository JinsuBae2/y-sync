package com.ync.ysync.controller;

import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeType;
import com.ync.ysync.service.NoticeService;
import com.ync.ysync.config.AuthUtil;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize; // 💡 추가
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile; // 💡 추가
import io.swagger.v3.oas.annotations.Operation;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/notices")
@RequiredArgsConstructor
public class NoticeController {

    private final NoticeService noticeService;
    private final AuthUtil authUtil;

    // 전체 공지사항 목록 조회
    @GetMapping
    public ResponseEntity<List<NoticeResponse>> getNotices() {
        List<NoticeResponse> responses = noticeService.getAllNotices().stream()
                .map(NoticeResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    // 💡 키워드를 통한 공지사항 검색 (제목 또는 내용 매칭)
    // - SecurityConfig에서 GET /api/v1/notices/** 패턴이 permitAll로 설정되어 있어 로그인 없이 접근 가능합니다.
    // - URL: GET /api/v1/notices/search?keyword=검색어
    @GetMapping("/search")
    public ResponseEntity<List<NoticeResponse>> searchNotices(@RequestParam(required = false) String keyword) {
        List<NoticeResponse> responses = noticeService.searchNotices(keyword).stream()
                .map(NoticeResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    @GetMapping("/{id}")
    public ResponseEntity<NoticeResponse> getNotice(@PathVariable Long id) {
        Notice notice = noticeService.getNotice(id);
        return ResponseEntity.ok(NoticeResponse.from(notice));
    }

    @Operation(summary = "공지사항 생성 (이미지 업로드 지원)", description = "관리자가 새로운 공지사항을 생성합니다. 첨부 이미지가 있을 경우 다중 업로드(Multipart)를 지원하며 전체 사용자에게 알림이 발송됩니다.")
    @PostMapping(consumes = {"multipart/form-data"})
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')") // 💡 관리자 전용
    public ResponseEntity<?> createNotice(
            @RequestPart("request") NoticeRequest request,
            @RequestPart(value = "images", required = false) List<MultipartFile> images) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        // 기본적으로 INTERNAL, 프론트에서 넘어오면 해당 값 사용 가능 (추가 확장)
        NoticeType type = NoticeType.INTERNAL;
        if (request.getNoticeType() != null) {
            type = NoticeType.valueOf(request.getNoticeType());
        }

        Notice notice = noticeService.createNotice(request.getTitle(), request.getContent(), type, request.getTargetGrade(), request.isPinned(), memberId, images);
        return ResponseEntity.ok(NoticeResponse.from(notice));
    }

    @Operation(summary = "공지사항 수정 (이미지 포함)", description = "관리자가 기존 공지사항을 수정합니다. 텍스트와 이미지 정보를 업데이트할 수 있습니다.")
    @PutMapping(value = "/{id}", consumes = {"multipart/form-data"})
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')") // 💡 관리자 전용
    public ResponseEntity<?> updateNotice(
            @PathVariable Long id,
            @RequestPart("request") NoticeRequest request,
            @RequestPart(value = "images", required = false) List<MultipartFile> images) {
        Long memberId = authUtil.getLoginMemberId();
        String roleStr = authUtil.getLoginMemberRole();
        if (memberId == null || roleStr == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        NoticeType type = NoticeType.INTERNAL;
        if (request.getNoticeType() != null) {
            type = NoticeType.valueOf(request.getNoticeType());
        }

        try {
            Notice notice = noticeService.updateNotice(id, request.getTitle(), request.getContent(), type, request.getTargetGrade(), request.isPinned(), memberId, MemberRole.valueOf(roleStr), images);
            return ResponseEntity.ok(NoticeResponse.from(notice));
        } catch (IllegalArgumentException e) {
            if (e.getMessage().contains("권한이 없습니다")) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage());
            }
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')") // 💡 관리자 전용
    public ResponseEntity<?> deleteNotice(@PathVariable Long id) {
        Long memberId = authUtil.getLoginMemberId();
        String roleStr = authUtil.getLoginMemberRole();
        if (memberId == null || roleStr == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        try {
            noticeService.deleteNotice(id, memberId, MemberRole.valueOf(roleStr));
            return ResponseEntity.ok("삭제 성공");
        } catch (IllegalArgumentException e) {
            if (e.getMessage().contains("권한이 없습니다")) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage());
            }
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class NoticeRequest {
        private String title;
        private String content;
        private String noticeType; // Optional, can be null
        private Grade targetGrade;
        private boolean isPinned;
    }
}
