package com.ync.ysync.repository;

import com.ync.ysync.domain.CalendarEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;

public interface CalendarEventRepository extends JpaRepository<CalendarEvent, Long> {
    
    // 💡 특정 기간(예: 조회하려는 월)에 걸쳐 있는 모든 일정을 조회합니다.
    // - 일정 시작일이 조회 기간 종료일보다 작거나 같고, 일정 종료일이 조회 기간 시작일보다 크거나 같아야 겹칩니다.
    List<CalendarEvent> findAllByStartDateLessThanEqualAndEndDateGreaterThanEqual(LocalDate endDate, LocalDate startDate);
}
