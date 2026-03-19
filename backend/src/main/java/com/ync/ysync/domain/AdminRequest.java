package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
@Table(name = "admin_request")
public class AdminRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member requester; // 💡 신청자

    @Column(columnDefinition = "TEXT", nullable = false)
    private String reason; // 💡 신청 사유

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RequestStatus status = RequestStatus.PENDING; // 💡 PENDING, APPROVED, REJECTED

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime requestedAt; // 💡 신청일

    private LocalDateTime processedAt; // 💡 처리일 (승인/거절 시점)

    @Builder
    public AdminRequest(Member requester, String reason) {
        this.requester = requester;
        this.reason = reason;
        this.status = RequestStatus.PENDING;
    }

    public enum RequestStatus {
        PENDING, APPROVED, REJECTED
    }

    // 💡 상태 변경 메서드
    public void approve() {
        this.status = RequestStatus.APPROVED;
        this.processedAt = LocalDateTime.now();
    }

    public void reject() {
        this.status = RequestStatus.REJECTED;
        this.processedAt = LocalDateTime.now();
    }
}
