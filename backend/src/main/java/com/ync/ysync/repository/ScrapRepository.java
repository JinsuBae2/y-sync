package com.ync.ysync.repository;

import com.ync.ysync.domain.Scrap;
import com.ync.ysync.domain.TargetType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ScrapRepository extends JpaRepository<Scrap, Long> {
    Optional<Scrap> findByMemberIdAndTargetTypeAndTargetId(Long memberId, TargetType targetType, Long targetId);
    
    List<Scrap> findAllByMemberIdOrderByCreatedAtDesc(Long memberId);

    // 💡 스크랩 해제를 조건부 DELETE 한 문장으로 처리하고 지워진 행 수를 돌려줍니다.
    //    엔티티를 조회해서 지우면 같은 행을 동시에 지우려는 두 요청 중 하나가
    //    ObjectOptimisticLockingFailureException("expected row count 1 but was 0")으로 500을 받습니다.
    //    "0행 삭제"는 오류가 아니므로 이 방식은 경쟁에서 져도 실패하지 않습니다.
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM Scrap s WHERE s.member.id = :memberId "
            + "AND s.targetType = :targetType AND s.targetId = :targetId")
    int deleteByMemberIdAndTargetTypeAndTargetId(@Param("memberId") Long memberId,
                                                 @Param("targetType") TargetType targetType,
                                                 @Param("targetId") Long targetId);
}
