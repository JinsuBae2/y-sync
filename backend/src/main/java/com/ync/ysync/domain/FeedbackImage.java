package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FeedbackImage {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false)
    private Long feedbackId;
    @Column(nullable = false, length = 30)
    private String contentType;
    // 💡 공개 업로드 경로 대신 DB에 보관하고 관리자 인증 API로만 제공합니다.
    @Lob @Column(nullable = false, length = 2097152)
    private byte[] data;

    public FeedbackImage(Long feedbackId, String contentType, byte[] data) {
        this.feedbackId = feedbackId;
        this.contentType = contentType;
        this.data = data;
    }
}
