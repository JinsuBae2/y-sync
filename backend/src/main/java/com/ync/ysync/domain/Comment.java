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
public class Comment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "notice_id", nullable = true) // 💡 공지사항 댓글일 경우 값이 들어갑니다. (커뮤니티 글일 경우 null)
    private Notice notice;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "community_post_id", nullable = true) // 💡 커뮤니티 게시글 댓글일 경우 값이 들어갑니다. (공지사항 글일 경우 null)
    private CommunityPost communityPost;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_id", nullable = true)
    private Comment parent;

    @OneToMany(mappedBy = "parent", cascade = CascadeType.ALL, orphanRemoval = true)
    private java.util.List<Comment> children = new java.util.ArrayList<>();

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;

    @Builder
    public Comment(String content, Notice notice, CommunityPost communityPost, Member member, Comment parent) {
        this.content = content;
        this.notice = notice;
        this.communityPost = communityPost;
        this.member = member;
        this.parent = parent;
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

    public void restoreByAdmin() {
        this.isDeleted = false;
        this.deletionReason = null;
    }
}
