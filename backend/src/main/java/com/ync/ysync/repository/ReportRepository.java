package com.ync.ysync.repository;

import com.ync.ysync.domain.Report;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.util.List;

public interface ReportRepository extends JpaRepository<Report, Long> {
    
    long countByTargetTypeAndTargetId(Report.TargetType targetType, Long targetId);
    
    boolean existsByReporterIdAndTargetTypeAndTargetId(Long reporterId, Report.TargetType targetType, Long targetId);

    @Query("SELECT r.targetType, r.targetId, COUNT(r) FROM Report r GROUP BY r.targetType, r.targetId ORDER BY COUNT(r) DESC")
    List<Object[]> findReportCountsGroupedByTarget();

    List<Report> findAllByTargetTypeAndTargetId(Report.TargetType targetType, Long targetId);
}
