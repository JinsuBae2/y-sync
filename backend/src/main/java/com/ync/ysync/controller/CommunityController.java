package com.ync.ysync.controller;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.service.CommunityService;
import com.ync.ysync.config.AuthUtil;
import lombok.AllArgsConstructor;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Data;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import io.swagger.v3.oas.annotations.Operation;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/community")
@RequiredArgsConstructor
public class CommunityController {

    private final CommunityService communityService;
    private final AuthUtil authUtil;

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
    @Operation(summary = "커뮤니티 게시글 생성 (파일 업로드 지원)", description = "학생이 새로운 게시글을 작성하며 여러 첨부파일을 업로드할 수 있습니다.")
    @PostMapping(consumes = {"multipart/form-data"})
    public ResponseEntity<?> createPost(
            @RequestPart("request") CommunityRequest request,
            @RequestPart(value = "images", required = false) List<MultipartFile> images,
            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        CommunityPost post = communityService.createPostWithImages(
                request.getCategory(),
                request.getTitle(),
                request.getContent(),
                request.isAnonymous(),
                request.getTargetGrade(),
                request.isPinned(),
                memberId,
                mergeFiles(images, files)
        );
        return ResponseEntity.ok(CommunityResponse.from(post));
    }

    // 작성자 본인이 게시글 내용과 설정을 수정하며 새 파일이 전달되면 기존 첨부를 교체합니다.
    @Operation(summary = "커뮤니티 게시글 수정", description = "작성자 본인이 기존 게시글과 첨부파일을 수정합니다.")
    @PutMapping(value = "/{id}", consumes = {"multipart/form-data"})
    public ResponseEntity<?> updatePost(
            @PathVariable Long id,
            @RequestPart("request") CommunityRequest request,
            @RequestPart(value = "images", required = false) List<MultipartFile> images,
            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        try {
            CommunityPost post = communityService.updatePost(
                    id,
                    request.getCategory(),
                    request.getTitle(),
                    request.getContent(),
                    request.isAnonymous(),
                    request.getTargetGrade(),
                    memberId,
                    mergeFiles(images, files)
            );
            return ResponseEntity.ok(CommunityResponse.from(post));
        } catch (IllegalArgumentException e) {
            if (e.getMessage().contains("권한이 없습니다")) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage());
            }
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    // 💡 게시글 삭제
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deletePost(@PathVariable Long id) {
        Long memberId = authUtil.getLoginMemberId();
        String roleStr = authUtil.getLoginMemberRole();
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
        @JsonProperty("isPinned")
        @JsonAlias("pinned")
        private boolean isPinned;
    }

    @Getter
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
        @Getter(AccessLevel.NONE)
        private boolean isDeleted;
        private String deletionReason;
        private String targetGrade;
        @Getter(AccessLevel.NONE)
        private boolean isPinned;
        private long viewCount;
        private long commentCount;
        private List<String> imageUrls;
        private List<AttachmentResponse> attachments;

        @JsonProperty("isDeleted")
        public boolean isDeleted() {
            return isDeleted;
        }

        @JsonProperty("isPinned")
        public boolean isPinned() {
            return isPinned;
        }

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
                    .imageUrls(post.getImages().stream().filter(com.ync.ysync.domain.PostImage::isImage).map(com.ync.ysync.domain.PostImage::getImageUrl).collect(Collectors.toList()))
                    .attachments(post.getImages().stream().map(file -> AttachmentResponse.builder()
                            .url(file.getImageUrl())
                            .originalFilename(file.getOriginalFilename() != null ? file.getOriginalFilename() : filenameFrom(file.getImageUrl()))
                            .contentType(file.getContentType())
                            .size(file.getFileSize())
                            .image(file.isImage())
                            .build()).collect(Collectors.toList()))
                    .build();
        }
    }

    private static List<MultipartFile> mergeFiles(List<MultipartFile> images, List<MultipartFile> files) {
        return java.util.stream.Stream.concat(
                images == null ? java.util.stream.Stream.empty() : images.stream(),
                files == null ? java.util.stream.Stream.empty() : files.stream()
        ).toList();
    }

    private static String filenameFrom(String url) {
        if (url == null) return "첨부파일";
        int slash = url.lastIndexOf('/');
        return slash >= 0 ? url.substring(slash + 1) : url;
    }
}
