package com.ync.ysync.controller;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
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

    // 💡 전체 공지사항 목록 조회 (Pageable 기반 무한 스크롤 및 검색 조합 지원)
    @GetMapping
    public ResponseEntity<org.springframework.data.domain.Page<NoticeResponse>> getNotices(
            @RequestParam(required = false) String keyword,
            org.springframework.data.domain.Pageable pageable) {
        
        org.springframework.data.domain.Page<Notice> noticePage = (keyword != null && !keyword.trim().isEmpty())
                ? noticeService.searchNotices(keyword, pageable)
                : noticeService.getAllNotices(pageable);
                
        org.springframework.data.domain.Page<NoticeResponse> responsePage = noticePage.map(NoticeResponse::from);
        return ResponseEntity.ok(responsePage);
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

    @Operation(summary = "공지사항 생성 (파일 업로드 지원)", description = "관리자가 여러 첨부파일과 함께 공지사항을 생성할 수 있습니다.")
    @PostMapping(consumes = {"multipart/form-data"})
    @PreAuthorize("hasRole('ADMIN')") // 💡 관리자 전용
    public ResponseEntity<?> createNotice(
            @RequestPart("request") NoticeRequest request,
            @RequestPart(value = "images", required = false) List<MultipartFile> images,
            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        // 기본적으로 NEWS, 프론트에서 넘어오면 해당 값 사용 가능 (추가 확장)
        NoticeType type = NoticeType.NEWS;
        if (request.getNoticeType() != null) {
            type = NoticeType.valueOf(request.getNoticeType());
        }

        Notice notice = noticeService.createNotice(request.getTitle(), request.getContent(), type, request.getTargetGrade(), request.isPinned(), request.getEventStartDate(), request.getEventEndDate(), memberId, mergeFiles(images, files));
        return ResponseEntity.ok(NoticeResponse.from(notice));
    }

    @Operation(summary = "공지사항 수정 (파일 포함)", description = "관리자가 기존 공지사항의 텍스트와 첨부파일을 업데이트할 수 있습니다.")
    @PutMapping(value = "/{id}", consumes = {"multipart/form-data"})
    @PreAuthorize("hasRole('ADMIN')") // 💡 관리자 전용
    public ResponseEntity<?> updateNotice(
            @PathVariable Long id,
            @RequestPart("request") NoticeRequest request,
            @RequestPart(value = "images", required = false) List<MultipartFile> images,
            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        Long memberId = authUtil.getLoginMemberId();
        String roleStr = authUtil.getLoginMemberRole();
        if (memberId == null || roleStr == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        NoticeType type = NoticeType.NEWS;
        if (request.getNoticeType() != null) {
            type = NoticeType.valueOf(request.getNoticeType());
        }

        try {
            Notice notice = noticeService.updateNotice(id, request.getTitle(), request.getContent(), type, request.getTargetGrade(), request.isPinned(), request.getEventStartDate(), request.getEventEndDate(), memberId, MemberRole.valueOf(roleStr), mergeFiles(images, files));
            return ResponseEntity.ok(NoticeResponse.from(notice));
        } catch (IllegalArgumentException e) {
            if (e.getMessage().contains("권한이 없습니다")) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage());
            }
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')") // 💡 관리자 전용
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
        @JsonProperty("isPinned")
        @JsonAlias("pinned")
        private boolean isPinned;
        private java.time.LocalDate eventStartDate;
        private java.time.LocalDate eventEndDate;
    }

    private static List<MultipartFile> mergeFiles(List<MultipartFile> images, List<MultipartFile> files) {
        return java.util.stream.Stream.concat(
                images == null ? java.util.stream.Stream.empty() : images.stream(),
                files == null ? java.util.stream.Stream.empty() : files.stream()
        ).toList();
    }
}
