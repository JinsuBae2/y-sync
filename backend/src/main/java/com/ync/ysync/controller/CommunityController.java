package com.ync.ysync.controller;

import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.Grade;
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
import org.springframework.web.multipart.MultipartFile;

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

    // 💡 키워드 기반 게시글 검색 API (카테고리와 조합 가능)
    @GetMapping("/search")
    public ResponseEntity<List<CommunityResponse>> searchPosts(
            @RequestParam String keyword,
            @RequestParam(required = false) String category) {
        List<CommunityResponse> responses = communityService.searchPosts(keyword, category).stream()
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
    @PostMapping(consumes = {"multipart/form-data"})
    public ResponseEntity<?> createPost(
            @RequestPart("request") CommunityRequest request,
            @RequestPart(value = "images", required = false) List<MultipartFile> images,
            HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        CommunityPost post = communityService.createPostWithImages(
                request.getCategory(),
                request.getTitle(),
                request.getContent(),
                request.isAnonymous(),
                request.getTargetGrade(),
                request.isPinned(),
                memberId,
                images
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
        private Grade targetGrade;
        private boolean isPinned;
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
        private boolean isDeleted;
        private String deletionReason;
        private String targetGrade;
        private boolean isPinned;
        private long viewCount;
        private long commentCount;
        private List<String> imageUrls;

        public static CommunityResponse from(CommunityPost post) {
            return CommunityResponse.builder()
                    .id(post.getId())
                    .category(post.getCategory())
                    .title(post.getTitle())
                    // 삭제된 경우 프론트에서 마스킹하거나 여기서 바로 가릴 수 있습니다
                    .content(post.getContent())
                    .anonymous(post.isAnonymous())
                    .authorName(post.isAnonymous() ? "익명의 학생" : post.getMember().getName())
                    .memberId(post.getMember().getId())
                    .createdAt(post.getCreatedAt())
                    .isDeleted(post.isDeleted())
                    .deletionReason(post.getDeletionReason())
                    .targetGrade(post.getTargetGrade() != null ? post.getTargetGrade().name() : Grade.ALL.name())
                    .isPinned(post.isPinned())
                    .viewCount(post.getViewCount())
                    .commentCount(post.getCommentCount())
                    .imageUrls(post.getImages().stream().map(com.ync.ysync.domain.PostImage::getImageUrl).collect(Collectors.toList()))
                    .build();
        }
    }
}
