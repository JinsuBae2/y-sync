package com.ync.ysync.controller;

import com.fasterxml.jackson.annotation.JsonProperty;
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
    @Getter(AccessLevel.NONE)
    private boolean isPinned;
    private long viewCount;
    private long commentCount;
    private java.util.List<String> imageUrls;
    private java.util.List<AttachmentResponse> attachments;
    private java.time.LocalDate eventStartDate;
    private java.time.LocalDate eventEndDate;

    @JsonProperty("isPinned")
    public boolean isPinned() {
        return isPinned;
    }

    @Builder
    public NoticeResponse(Long id, String title, String content, String authorName, String noticeType, LocalDateTime createdAt, LocalDateTime updatedAt, String targetGrade, boolean isPinned, long viewCount, long commentCount, java.util.List<String> imageUrls, java.util.List<AttachmentResponse> attachments, java.time.LocalDate eventStartDate, java.time.LocalDate eventEndDate) {
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
        this.attachments = attachments;
        this.eventStartDate = eventStartDate;
        this.eventEndDate = eventEndDate;
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
                .imageUrls(notice.getImages().stream().filter(com.ync.ysync.domain.NoticeImage::isImage).map(com.ync.ysync.domain.NoticeImage::getImageUrl).collect(java.util.stream.Collectors.toList()))
                .attachments(notice.getImages().stream().map(file -> AttachmentResponse.builder()
                        .url(file.getImageUrl())
                        .originalFilename(file.getOriginalFilename() != null ? file.getOriginalFilename() : filenameFrom(file.getImageUrl()))
                        .contentType(file.getContentType())
                        .size(file.getFileSize())
                        .image(file.isImage())
                        .build()).collect(java.util.stream.Collectors.toList()))
                .eventStartDate(notice.getEventStartDate())
                .eventEndDate(notice.getEventEndDate())
                .build();
    }

    private static String filenameFrom(String url) {
        if (url == null) return "첨부파일";
        int slash = url.lastIndexOf('/');
        return slash >= 0 ? url.substring(slash + 1) : url;
    }
}
