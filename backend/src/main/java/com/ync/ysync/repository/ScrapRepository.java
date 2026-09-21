package com.ync.ysync.repository;

import com.ync.ysync.domain.Scrap;
import com.ync.ysync.domain.TargetType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ScrapRepository extends JpaRepository<Scrap, Long> {
    Optional<Scrap> findByMemberIdAndTargetTypeAndTargetId(Long memberId, TargetType targetType, Long targetId);
    
    List<Scrap> findAllByMemberIdOrderByCreatedAtDesc(Long memberId);

    // 💡 대상 글이 하드 삭제될 때 그 글을 가리키던 스크랩을 함께 정리합니다.
    //    scrap.target_id 에는 FK가 없어 DB가 막아 주지 않습니다.
    void deleteAllByTargetTypeAndTargetId(TargetType targetType, Long targetId);
}
