package com.ync.ysync.repository;

import com.ync.ysync.domain.Report;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface ReportRepository extends JpaRepository<Report, Long> {
    
    long countByTargetTypeAndTargetId(Report.TargetType targetType, Long targetId);
    
    boolean existsByReporterIdAndTargetTypeAndTargetId(Long reporterId, Report.TargetType targetType, Long targetId);

    @Query("SELECT r.targetType, r.targetId, COUNT(r) FROM Report r GROUP BY r.targetType, r.targetId ORDER BY COUNT(r) DESC")
    List<Object[]> findReportCountsGroupedByTarget();

    List<Report> findAllByTargetTypeAndTargetId(Report.TargetType targetType, Long targetId);

    void deleteByTargetTypeAndTargetId(Report.TargetType targetType, Long targetId);

    // 💡 대상 글이 하드 삭제될 때 그 글의 댓글을 가리키던 신고를 한 번에 정리합니다.
    //    report.target_id 에는 FK가 없어 DB가 막아 주지 않고, 남으면 관리자 신고함에
    //    열 수 없는 항목이 계속 쌓입니다. 빈 목록으로 호출하지 않도록 호출부에서 거릅니다.
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM Report r WHERE r.targetType = :targetType AND r.targetId IN :targetIds")
    void deleteAllByTargetTypeAndTargetIdIn(@Param("targetType") Report.TargetType targetType,
                                            @Param("targetIds") List<Long> targetIds);
}
