package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Feedback {
    public enum Category { BUG, SUGGESTION, OTHER }

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    // 💡 회원 탈퇴를 막지 않도록 식별자만 저장하며 이름·학번은 복제하지 않습니다.
    @Column(nullable = false)
    private Long memberId;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    private Category category;
    @Column(nullable = false, length = 100)
    private String title;
    @Column(nullable = false, length = 3000)
    private String content;
    @Column(nullable = false, length = 100)
    private String screen;
    @Column(nullable = false, length = 300)
    private String clientInfo;
    @Column(nullable = false)
    private boolean reviewed;
    @Column(nullable = false)
    private LocalDateTime createdAt;

    public Feedback(Long memberId, Category category, String title, String content,
                    String screen, String clientInfo) {
        this.memberId = memberId;
        this.category = category;
        this.title = title;
        this.content = content;
        this.screen = screen;
        this.clientInfo = clientInfo;
        this.createdAt = LocalDateTime.now();
    }

    public void markReviewed() { reviewed = true; }
}
