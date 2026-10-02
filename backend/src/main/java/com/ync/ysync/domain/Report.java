package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
// 💡 같은 회원이 같은 대상을 중복 신고할 수 없도록 DB 차원에서 막습니다.
//    중복 신고가 적재되면 누적 신고 수가 부풀려져 자동 블라인드 임계(5회)가 실제보다 적은 인원으로 도달합니다.
@Table(name = "report", uniqueConstraints = @UniqueConstraint(
        name = "uq_report", columnNames = {"reporter_id", "target_type", "target_id"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class Report {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reporter_id", nullable = false)
    private Member reporter;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TargetType targetType; // POST, COMMENT

    @Column(nullable = false)
    private Long targetId;

    @Column(nullable = false)
    private String reason;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    public enum TargetType {
        POST, COMMENT
    }

    @Builder
    public Report(Member reporter, TargetType targetType, Long targetId, String reason) {
        this.reporter = reporter;
        this.targetType = targetType;
        this.targetId = targetId;
        this.reason = reason;
    }
}
