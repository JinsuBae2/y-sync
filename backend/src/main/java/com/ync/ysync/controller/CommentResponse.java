package com.ync.ysync.controller;

import com.ync.ysync.domain.Comment;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CommentResponse {
    private Long id;
    private String content;
    private Long noticeId;
    private Long communityPostId; // 💡 커뮤니티 게시글 ID를 추가합니다.
    private Long memberId;
    private String authorName;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private boolean isDeleted;
    private String deletionReason;

    @Builder
    public CommentResponse(Long id, String content, Long noticeId, Long communityPostId, Long memberId, String authorName, LocalDateTime createdAt, LocalDateTime updatedAt, boolean isDeleted, String deletionReason) {
        this.id = id;
        this.content = content;
        this.noticeId = noticeId;
        this.communityPostId = communityPostId;
        this.memberId = memberId;
        this.authorName = authorName;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.isDeleted = isDeleted;
        this.deletionReason = deletionReason;
    }

    public static CommentResponse from(Comment comment) {
        return CommentResponse.builder()
                .id(comment.getId())
                .content(comment.getContent())
                .noticeId(comment.getNotice() != null ? comment.getNotice().getId() : null) // 💡 Null 체크 추가
                .communityPostId(comment.getCommunityPost() != null ? comment.getCommunityPost().getId() : null) // 💡 필드 추가
                .memberId(comment.getMember().getId())
                .authorName(comment.getMember().getName())
                .createdAt(comment.getCreatedAt())
                .updatedAt(comment.getUpdatedAt())
                .isDeleted(comment.isDeleted())
                .deletionReason(comment.getDeletionReason())
                .build();
    }
}
