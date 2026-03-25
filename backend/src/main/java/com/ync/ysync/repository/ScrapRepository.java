package com.ync.ysync.repository;

import com.ync.ysync.domain.Scrap;
import com.ync.ysync.domain.TargetType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ScrapRepository extends JpaRepository<Scrap, Long> {
    Optional<Scrap> findByMemberIdAndTargetTypeAndTargetId(Long memberId, TargetType targetType, Long targetId);
    
    List<Scrap> findAllByMemberIdOrderByCreatedAtDesc(Long memberId);
}
