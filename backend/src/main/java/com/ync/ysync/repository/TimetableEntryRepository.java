package com.ync.ysync.repository;

import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.TimetableEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.DayOfWeek;
import java.util.List;

public interface TimetableEntryRepository extends JpaRepository<TimetableEntry, Long> {
    
    // 💡 특정 학년의 시간표 목록 조회
    List<TimetableEntry> findAllByGrade(Grade grade);
    
    // 💡 특정 학년, 요일에 새 수업이 기존 수업들과 교시가 겹치는지 검증하는 JPQL 쿼리
    // - overlap 조건: (기존 startPeriod <= 새 endPeriod) AND (기존 endPeriod >= 새 startPeriod)
    @Query("SELECT COUNT(t) > 0 FROM TimetableEntry t " +
           "WHERE t.grade = :grade AND t.dayOfWeek = :dayOfWeek " +
           "AND t.startPeriod <= :endPeriod AND t.endPeriod >= :startPeriod")
    boolean existsOverlapping(
            @Param("grade") Grade grade,
            @Param("dayOfWeek") DayOfWeek dayOfWeek,
            @Param("startPeriod") int startPeriod,
            @Param("endPeriod") int endPeriod
    );

    // 💡 특정 시간표 항목을 업데이트할 때, 본인을 제외한 다른 수업들과 겹치는지 검증
    @Query("SELECT COUNT(t) > 0 FROM TimetableEntry t " +
           "WHERE t.grade = :grade AND t.dayOfWeek = :dayOfWeek " +
           "AND t.startPeriod <= :endPeriod AND t.endPeriod >= :startPeriod " +
           "AND t.id <> :excludeId")
    boolean existsOverlappingWithExclude(
            @Param("grade") Grade grade,
            @Param("dayOfWeek") DayOfWeek dayOfWeek,
            @Param("startPeriod") int startPeriod,
            @Param("endPeriod") int endPeriod,
            @Param("excludeId") Long excludeId
    );
}
