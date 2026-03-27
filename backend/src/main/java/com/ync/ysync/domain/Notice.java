package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class Notice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    private Member author;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private NoticeType noticeType;

    @Column(columnDefinition = "TEXT")
    private String aiSummary;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Grade targetGrade = Grade.ALL;

    @Column(nullable = false)
    private boolean isPinned = false;

    @Column(nullable = false)
    private long viewCount = 0L;

    @Column(nullable = false)
    private long commentCount = 0L;

    // 💡 공지사항에 첨부된 이미지 목록 (1:N 양방향 매핑, 부모 엔티티 삭제시 고아 객체 함께 삭제)
    @OneToMany(mappedBy = "notice", cascade = CascadeType.ALL, orphanRemoval = true)
    private java.util.List<NoticeImage> images = new java.util.ArrayList<>();

    public void incrementViewCount() {
        this.viewCount++;
    }

    public void incrementCommentCount() {
        this.commentCount++;
    }

    public void decrementCommentCount() {
        if (this.commentCount > 0) {
            this.commentCount--;
        }
    }

    @Builder
    public Notice(String title, String content, Member author, NoticeType noticeType, String aiSummary, Grade targetGrade, boolean isPinned) {
        this.title = title;
        this.content = content;
        this.author = author;
        this.noticeType = noticeType;
        this.aiSummary = aiSummary;
        this.targetGrade = targetGrade != null ? targetGrade : Grade.ALL;
        this.isPinned = isPinned;
    }

    public void update(String title, String content, NoticeType noticeType, Grade targetGrade, boolean isPinned) {
        this.title = title;
        this.content = content;
        this.noticeType = noticeType;
        if (targetGrade != null) this.targetGrade = targetGrade;
        this.isPinned = isPinned;
    }
}
