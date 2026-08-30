package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

// 기존 이미지 데이터와 호환하면서 공지사항의 범용 첨부파일을 관리합니다.
@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class NoticeImage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 💡 이미지의 접근 URL (예: /uploads/abcde.jpg)
    @Column(nullable = false)
    private String imageUrl;

    private String originalFilename;

    private String contentType;

    private Long fileSize;

    // 💡 여러 이미지가 하나의 공지사항에 속하도록 N:1 매핑 설정
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "notice_id", nullable = false)
    private Notice notice;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public NoticeImage(String imageUrl, String originalFilename, String contentType, Long fileSize,
                       Notice notice) {
        this.imageUrl = imageUrl;
        this.originalFilename = originalFilename;
        this.contentType = contentType;
        this.fileSize = fileSize;
        this.notice = notice;
    }

    public boolean isImage() {
        if (contentType != null) return contentType.startsWith("image/");
        return imageUrl != null && imageUrl.toLowerCase().matches(".*\\.(png|jpe?g|gif|webp|bmp)$");
    }
}
