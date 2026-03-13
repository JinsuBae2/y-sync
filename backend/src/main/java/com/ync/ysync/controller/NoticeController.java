package com.ync.ysync.controller;

import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeType;
import com.ync.ysync.repository.NoticeRepository;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class NoticeController {

    private final NoticeRepository noticeRepository;

    @GetMapping("/notices")
    public ResponseEntity<List<Notice>> getNotices() {
        return ResponseEntity.ok(noticeRepository.findAllByOrderByCreatedAtDesc());
    }

    @PostMapping("/admin/notices")
    public ResponseEntity<Notice> createNotice(@RequestBody NoticeCreateRequest request) {
        Notice notice = Notice.builder()
                .title(request.getTitle())
                .content(request.getContent())
                .author(request.getAuthor())
                .noticeType(NoticeType.INTERNAL) // 기본값으로 INTERNAL 설정
                .build();
        return ResponseEntity.ok(noticeRepository.save(notice));
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class NoticeCreateRequest {
        private String title;
        private String content;
        private String author;
    }
}
