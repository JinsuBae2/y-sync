package com.ync.ysync.controller;

import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.service.CommunityService;
import jakarta.servlet.http.HttpSession;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/community")
@RequiredArgsConstructor
public class CommunityController {

    private final CommunityService communityService;

    // 💡 게시글 목록 조회 (카테고리 필터링 포함)
    @GetMapping
    public ResponseEntity<List<CommunityResponse>> getPosts(@RequestParam(required = false) String category) {
        List<CommunityResponse> responses = communityService.getPosts(category).stream()
                .map(CommunityResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    // 💡 게시글 단건 상세 조회
    @GetMapping("/{id}")
    public ResponseEntity<CommunityResponse> getPost(@PathVariable Long id) {
        CommunityPost post = communityService.getPost(id);
        return ResponseEntity.ok(CommunityResponse.from(post));
    }

    // 💡 게시글 작성
    @PostMapping
    public ResponseEntity<?> createPost(@RequestBody CommunityRequest request, HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        CommunityPost post = communityService.createPost(
                request.getCategory(),
                request.getTitle(),
                request.getContent(),
                request.isAnonymous(),
                memberId
        );
        return ResponseEntity.ok(CommunityResponse.from(post));
    }

    // 💡 게시글 삭제
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deletePost(@PathVariable Long id, HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        String roleStr = (String) session.getAttribute("loginMemberRole");
        if (memberId == null || roleStr == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        try {
            communityService.deletePost(id, memberId, MemberRole.valueOf(roleStr));
            return ResponseEntity.ok("삭제 성공");
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage());
        }
    }

    // --- DTO ---

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CommunityRequest {
        private String category;
        private String title;
        private String content;
        private boolean anonymous;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class CommunityResponse {
        private Long id;
        private String category;
        private String title;
        private String content;
        private boolean anonymous;
        private String authorName;
        private Long memberId;
        private LocalDateTime createdAt;

        public static CommunityResponse from(CommunityPost post) {
            return CommunityResponse.builder()
                    .id(post.getId())
                    .category(post.getCategory())
                    .title(post.getTitle())
                    .content(post.getContent())
                    .anonymous(post.isAnonymous())
                    // 💡 익명일 경우 이름을 필터링하여 프론트로 보냄 (혹은 프론트에서 처리 가능)
                    .authorName(post.isAnonymous() ? "익명의 학생" : post.getMember().getName())
                    .memberId(post.getMember().getId())
                    .createdAt(post.getCreatedAt())
                    .build();
        }
    }
}
