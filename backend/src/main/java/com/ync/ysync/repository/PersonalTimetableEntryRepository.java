package com.ync.ysync.repository;

import com.ync.ysync.domain.PersonalTimetableEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.DayOfWeek;
import java.util.List;
import java.util.Optional;

public interface PersonalTimetableEntryRepository extends JpaRepository<PersonalTimetableEntry, Long> {

    List<PersonalTimetableEntry> findAllByMemberId(Long memberId);

    Optional<PersonalTimetableEntry> findByIdAndMemberId(Long id, Long memberId);

    @Query("SELECT COUNT(t) > 0 FROM PersonalTimetableEntry t " +
            "WHERE t.member.id = :memberId AND t.dayOfWeek = :dayOfWeek " +
            "AND t.startPeriod <= :endPeriod AND t.endPeriod >= :startPeriod")
    boolean existsOverlapping(
            @Param("memberId") Long memberId,
            @Param("dayOfWeek") DayOfWeek dayOfWeek,
            @Param("startPeriod") int startPeriod,
            @Param("endPeriod") int endPeriod
    );

    @Query("SELECT COUNT(t) > 0 FROM PersonalTimetableEntry t " +
            "WHERE t.member.id = :memberId AND t.dayOfWeek = :dayOfWeek " +
            "AND t.startPeriod <= :endPeriod AND t.endPeriod >= :startPeriod " +
            "AND t.id <> :excludeId")
    boolean existsOverlappingWithExclude(
            @Param("memberId") Long memberId,
            @Param("dayOfWeek") DayOfWeek dayOfWeek,
            @Param("startPeriod") int startPeriod,
            @Param("endPeriod") int endPeriod,
            @Param("excludeId") Long excludeId
    );
}
