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

// 💡 커뮤니티(자유게시판) 게시물 엔티티입니다.
@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class CommunityPost {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 💡 게시물 카테고리: Q&A, 팀원모집, 자유 등 Enum으로 관리 혹은 String으로 관리 가능.
    // 여기서는 편리한 확장을 위해 String으로 선언합니다.
    @Column(nullable = false)
    private String category;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    // 💡 익명 작성 여부 플래그입니다. true일 경우 프론트엔드에서 닉네임을 노출하지 않습니다.
    @Column(nullable = false)
    private boolean anonymous;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

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

    // 💡 게시물에 첨부된 이미지 목록 (1:N 양방향 매핑, 부모 엔티티 삭제시 고아 객체 함께 삭제)
    @OneToMany(mappedBy = "communityPost", cascade = CascadeType.ALL, orphanRemoval = true)
    private java.util.List<PostImage> images = new java.util.ArrayList<>();

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
    public CommunityPost(String category, String title, String content, boolean anonymous, Member member,
            Grade targetGrade, boolean isPinned) {
        this.category = category;
        this.title = title;
        this.content = content;
        this.anonymous = anonymous;
        this.member = member;
        this.targetGrade = targetGrade != null ? targetGrade : Grade.ALL;
        this.isPinned = isPinned;
    }

    // 💡 작성된 글을 수정하는 메서드
    public void update(String category, String title, String content, boolean anonymous) {
        this.category = category;
        this.title = title;
        this.content = content;
        this.anonymous = anonymous;
    }

    // 관리자 삭제 필드
    @Column(nullable = false)
    private boolean isDeleted = false;

    @Column(columnDefinition = "TEXT")
    private String deletionReason;

    public void deleteByAdmin(String reason) {
        this.isDeleted = true;
        this.deletionReason = reason;
    }
}
