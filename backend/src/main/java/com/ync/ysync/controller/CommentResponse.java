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
    private Long memberId;
    private String authorName;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @Builder
    public CommentResponse(Long id, String content, Long noticeId, Long memberId, String authorName, LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.id = id;
        this.content = content;
        this.noticeId = noticeId;
        this.memberId = memberId;
        this.authorName = authorName;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public static CommentResponse from(Comment comment) {
        return CommentResponse.builder()
                .id(comment.getId())
                .content(comment.getContent())
                .noticeId(comment.getNotice().getId())
                .memberId(comment.getMember().getId())
                .authorName(comment.getMember().getName())
                .createdAt(comment.getCreatedAt())
                .updatedAt(comment.getUpdatedAt())
                .build();
    }
}
