package com.ync.ysync.repository;

import com.ync.ysync.domain.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    
    // 특정 회원의 알림 목록을 최신순으로 조회
    List<Notification> findByMemberIdOrderByCreatedAtDesc(Long memberId);

    // 로그인한 회원의 읽지 않은 모든 알림을 한 번에 읽음 처리
    @Modifying(clearAutomatically = true)
    @Query("update Notification n set n.isRead = true where n.member.id = :memberId and n.isRead = false")
    int markAllAsReadByMemberId(@Param("memberId") Long memberId);

    // 본인 소유의 알림인지 검증하여 삭제하기 위한 메소드
    void deleteByIdAndMemberId(Long id, Long memberId);
}
