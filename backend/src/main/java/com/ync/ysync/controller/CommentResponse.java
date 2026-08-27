package com.ync.ysync.controller;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.ync.ysync.domain.Comment;
import com.ync.ysync.domain.CommentDeletedBy;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

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
    @Getter(AccessLevel.NONE)
    private boolean isDeleted;
    private String deletionReason;
    private CommentDeletedBy deletedBy;
    private Long parentId; // 💡 부모 댓글 ID 추가
    
    @Setter
    private List<CommentResponse> children = new ArrayList<>();

    @JsonProperty("isDeleted")
    public boolean isDeleted() {
        return isDeleted;
    }

    @Builder
    public CommentResponse(Long id, String content, Long noticeId, Long communityPostId, Long memberId, String authorName, LocalDateTime createdAt, LocalDateTime updatedAt, boolean isDeleted, String deletionReason, CommentDeletedBy deletedBy, Long parentId) {
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
        this.deletedBy = deletedBy;
        this.parentId = parentId;
    }

    public static CommentResponse from(Comment comment) {
        boolean deleted = comment.isDeleted();

        return CommentResponse.builder()
                .id(comment.getId())
                .content(deleted ? "삭제된 댓글입니다." : comment.getContent())
                .noticeId(comment.getNotice() != null ? comment.getNotice().getId() : null) // 💡 Null 체크 추가
                .communityPostId(comment.getCommunityPost() != null ? comment.getCommunityPost().getId() : null) // 💡 필드 추가
                .memberId(deleted ? null : comment.getMember().getId())
                .authorName(deleted ? "삭제된 댓글" : comment.getMember().getName())
                .createdAt(comment.getCreatedAt())
                .updatedAt(comment.getUpdatedAt())
                .isDeleted(comment.isDeleted())
                .deletionReason(comment.getDeletionReason())
                .deletedBy(comment.getDeletedBy())
                .parentId(comment.getParent() != null ? comment.getParent().getId() : null) // 💡 parentId 파싱 추가
                .build();
    }
}
