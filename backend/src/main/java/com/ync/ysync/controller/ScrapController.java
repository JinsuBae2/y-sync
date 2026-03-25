package com.ync.ysync.controller;

import com.ync.ysync.domain.TargetType;
import com.ync.ysync.service.ScrapService;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/scraps")
@RequiredArgsConstructor
public class ScrapController {

    private final ScrapService scrapService;

    // 💡 스크랩 토글 (추가/삭제) API
    @PostMapping
    public ResponseEntity<?> toggleScrap(
            @RequestParam TargetType targetType,
            @RequestParam Long targetId,
            HttpSession session) {
        
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");
        }

        try {
            scrapService.toggleScrap(memberId, targetType, targetId);
            return ResponseEntity.ok("스크랩 토글 성공");
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    // 💡 내 스크랩 목록 조회 API
    @GetMapping
    public ResponseEntity<?> getMyScraps(HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");
        }

        List<ScrapService.ScrapResponseDto> scraps = scrapService.getMyScraps(memberId);
        return ResponseEntity.ok(scraps);
    }
}
