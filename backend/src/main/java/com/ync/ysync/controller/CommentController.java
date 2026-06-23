package com.ync.ysync.controller;

import com.ync.ysync.domain.Comment;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.service.CommentService;
import com.ync.ysync.config.AuthUtil;
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
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;
    private final AuthUtil authUtil;

    // 공지사항 별 댓글 조회 (대댓글 계층형 반환)
    @GetMapping("/notices/{noticeId}/comments")
    public ResponseEntity<List<CommentResponse>> getComments(@PathVariable Long noticeId) {
        List<CommentResponse> responses = commentService.getCommentTreeByNoticeId(noticeId);
        return ResponseEntity.ok(responses);
    }

    // 💡 커뮤니티 게시글 별 댓글 조회 (대댓글 계층형 반환)
    @GetMapping("/community/{postId}/comments")
    public ResponseEntity<List<CommentResponse>> getCommunityComments(@PathVariable Long postId) {
        List<CommentResponse> responses = commentService.getCommentTreeByCommunityPostId(postId);
        return ResponseEntity.ok(responses);
    }

    // 댓글 작성
    @PostMapping("/notices/{noticeId}/comments")
    public ResponseEntity<?> createComment(
            @PathVariable Long noticeId,
            @RequestBody CommentRequest request) {
        
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        // 빈 내용 검증
        if (request.getContent() == null || request.getContent().trim().isEmpty()) {
            return ResponseEntity.badRequest().body("댓글 내용을 입력해주세요.");
        }

        Comment comment = commentService.createComment(noticeId, memberId, request.getContent().trim(), request.getParentId());
        return ResponseEntity.ok(CommentResponse.from(comment));
    }

    // 💡 커뮤니티 게시글 댓글 작성
    @PostMapping("/community/{postId}/comments")
    public ResponseEntity<?> createCommunityComment(
            @PathVariable Long postId,
            @RequestBody CommentRequest request) {
        
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        // 빈 내용 검증
        if (request.getContent() == null || request.getContent().trim().isEmpty()) {
            return ResponseEntity.badRequest().body("댓글 내용을 입력해주세요.");
        }

        Comment comment = commentService.createCommunityComment(postId, memberId, request.getContent().trim(), request.getParentId());
        return ResponseEntity.ok(CommentResponse.from(comment));
    }

    // 댓글 삭제
    @DeleteMapping("/comments/{commentId}")
    public ResponseEntity<?> deleteComment(@PathVariable Long commentId) {
        Long memberId = authUtil.getLoginMemberId();
        String roleStr = authUtil.getLoginMemberRole();
        if (memberId == null || roleStr == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        try {
            commentService.deleteComment(commentId, memberId, MemberRole.valueOf(roleStr));
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
    public static class CommentRequest {
        private String content;
        private Long parentId; // 💡 대댓글을 위한 부모 댓글 ID
    }
}
