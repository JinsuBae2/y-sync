package com.ync.ysync.repository;

import com.ync.ysync.domain.AdminRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface AdminRequestRepository extends JpaRepository<AdminRequest, Long> {
    
    // 💡 특정 상태의 신청 목록을 신청일 역순으로 조회합니다. (관리자 확인용)
    List<AdminRequest> findAllByStatusOrderByRequestedAtDesc(AdminRequest.RequestStatus status);
    
    // 💡 특정 사용자의 가장 최근 신청 건을 조회합니다. (중복 신청 방지용)
    Optional<AdminRequest> findTopByRequesterIdOrderByRequestedAtDesc(Long requesterId);
}
