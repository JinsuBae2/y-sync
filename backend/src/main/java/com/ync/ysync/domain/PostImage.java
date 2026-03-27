package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

// 💡 게시글에 포함된 이미지를 관리하는 엔티티입니다.
@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class PostImage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 💡 이미지의 접근 URL (예: /uploads/abcde.jpg)
    @Column(nullable = false)
    private String imageUrl;

    // 💡 여러 이미지가 하나의 게시글(CommunityPost)에 속하도록 N:1 매핑 설정
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "community_post_id", nullable = false)
    private CommunityPost communityPost;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public PostImage(String imageUrl, CommunityPost communityPost) {
        this.imageUrl = imageUrl;
        this.communityPost = communityPost;
    }
}
