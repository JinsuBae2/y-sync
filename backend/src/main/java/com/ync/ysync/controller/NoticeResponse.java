package com.ync.ysync.controller;

import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Notice;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class NoticeResponse {
    private Long id;
    private String title;
    private String content;
    private String authorName;
    private String noticeType;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private String targetGrade;
    private boolean isPinned;
    private long viewCount;
    private long commentCount;
    private java.util.List<String> imageUrls; // 💡 추가

    @Builder
    public NoticeResponse(Long id, String title, String content, String authorName, String noticeType, LocalDateTime createdAt, LocalDateTime updatedAt, String targetGrade, boolean isPinned, long viewCount, long commentCount, java.util.List<String> imageUrls) {
        this.id = id;
        this.title = title;
        this.content = content;
        this.authorName = authorName;
        this.noticeType = noticeType;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.targetGrade = targetGrade;
        this.isPinned = isPinned;
        this.viewCount = viewCount;
        this.commentCount = commentCount;
        this.imageUrls = imageUrls;
    }

    public static NoticeResponse from(Notice notice) {
        return NoticeResponse.builder()
                .id(notice.getId())
                .title(notice.getTitle())
                .content(notice.getContent())
                .authorName(notice.getAuthor().getName())
                .noticeType(notice.getNoticeType().name())
                .createdAt(notice.getCreatedAt())
                .updatedAt(notice.getUpdatedAt())
                .targetGrade(notice.getTargetGrade() != null ? notice.getTargetGrade().name() : Grade.ALL.name())
                .isPinned(notice.isPinned())
                .viewCount(notice.getViewCount())
                .commentCount(notice.getCommentCount())
                .imageUrls(notice.getImages().stream().map(com.ync.ysync.domain.NoticeImage::getImageUrl).collect(java.util.stream.Collectors.toList()))
                .build();
    }
}
