package com.ync.ysync.controller;

import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeType;
import com.ync.ysync.service.NoticeService;
import jakarta.servlet.http.HttpSession;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/notices")
@RequiredArgsConstructor
public class NoticeController {

    private final NoticeService noticeService;

    @GetMapping
    public ResponseEntity<List<NoticeResponse>> getNotices() {
        List<NoticeResponse> responses = noticeService.getAllNotices().stream()
                .map(NoticeResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    @GetMapping("/{id}")
    public ResponseEntity<NoticeResponse> getNotice(@PathVariable Long id) {
        Notice notice = noticeService.getNotice(id);
        return ResponseEntity.ok(NoticeResponse.from(notice));
    }

    @PostMapping
    public ResponseEntity<?> createNotice(@RequestBody NoticeRequest request, HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        // 기본적으로 INTERNAL, 프론트에서 넘어오면 해당 값 사용 가능 (추가 확장)
        NoticeType type = NoticeType.INTERNAL;
        if (request.getNoticeType() != null) {
            type = NoticeType.valueOf(request.getNoticeType());
        }

        Notice notice = noticeService.createNotice(request.getTitle(), request.getContent(), type, memberId);
        return ResponseEntity.ok(NoticeResponse.from(notice));
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> updateNotice(@PathVariable Long id, @RequestBody NoticeRequest request, HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        String roleStr = (String) session.getAttribute("loginMemberRole");
        if (memberId == null || roleStr == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        NoticeType type = NoticeType.INTERNAL;
        if (request.getNoticeType() != null) {
            type = NoticeType.valueOf(request.getNoticeType());
        }

        try {
            Notice notice = noticeService.updateNotice(id, request.getTitle(), request.getContent(), type, memberId, MemberRole.valueOf(roleStr));
            return ResponseEntity.ok(NoticeResponse.from(notice));
        } catch (IllegalArgumentException e) {
            if (e.getMessage().contains("권한이 없습니다")) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage());
            }
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteNotice(@PathVariable Long id, HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        String roleStr = (String) session.getAttribute("loginMemberRole");
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
    }
}
