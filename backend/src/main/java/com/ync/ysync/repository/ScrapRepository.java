package com.ync.ysync.repository;

import com.ync.ysync.domain.Scrap;
import com.ync.ysync.domain.TargetType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ScrapRepository extends JpaRepository<Scrap, Long> {
    Optional<Scrap> findByMemberIdAndTargetTypeAndTargetId(Long memberId, TargetType targetType, Long targetId);
    
    List<Scrap> findAllByMemberIdOrderByCreatedAtDesc(Long memberId);

    // 💡 탈퇴 처리 시 스크랩을 모두 지웁니다. 본인만 보는 데이터라 남길 이유가 없습니다.
    void deleteAllByMemberId(Long memberId);
}
