package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
// 💡 같은 회원이 같은 대상을 중복 스크랩할 수 없도록 DB 차원에서 막습니다.
//    "조회 후 INSERT" 구조라 동시 요청이 들어오면 애플리케이션 검사만으로는 중복행을 막지 못하고,
//    중복행이 한 번 생기면 findBy... 조회가 영구히 실패합니다.
@Table(name = "scrap", uniqueConstraints = @UniqueConstraint(
        name = "uq_scrap", columnNames = {"member_id", "target_type", "target_id"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
public class Scrap {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TargetType targetType;

    @Column(nullable = false)
    private Long targetId;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;
}
