package com.ync.ysync.service;

import com.ync.ysync.domain.CalendarEvent;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.repository.CalendarEventRepository;
import com.ync.ysync.repository.NoticeRepository;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CalendarService {

    private final CalendarEventRepository calendarEventRepository;
    private final NoticeRepository noticeRepository;

    // 💡 학사 일정과 일정이 연동된 공지사항을 병합 및 정렬하여 조회합니다.
    public List<CalendarEventResponse> getEvents(LocalDate startDate, LocalDate endDate) {
        List<CalendarEventResponse> responses = new ArrayList<>();

        // 1. 일반 학사 일정 조회
        List<CalendarEvent> academicEvents = calendarEventRepository.findAllByStartDateLessThanEqualAndEndDateGreaterThanEqual(endDate, startDate);
        for (CalendarEvent event : academicEvents) {
            responses.add(new CalendarEventResponse(
                    event.getId(),
                    event.getTitle(),
                    event.getDescription(),
                    event.getStartDate(),
                    event.getEndDate(),
                    "ACADEMIC",
                    null,
                    event.getColor()
            ));
        }

        // 2. 일정이 등록된 공지사항 조회
        List<Notice> noticeEvents = noticeRepository.findAllByEventStartDateLessThanEqualAndEventEndDateGreaterThanEqual(endDate, startDate);
        for (Notice notice : noticeEvents) {
            responses.add(new CalendarEventResponse(
                    notice.getId(), // 프론트의 NoticeDetail 이동을 돕기 위해 공지사항 ID 사용
                    notice.getTitle(),
                    notice.getContent(),
                    notice.getEventStartDate(),
                    notice.getEventEndDate(),
                    "NOTICE",
                    notice.getId(),
                    "#34C759" // 공지사항 일정은 연두색/녹색으로 고정 표시
            ));
        }

        // 3. 일정 시작일 기준 오름차순 정렬
        responses.sort(Comparator.comparing(CalendarEventResponse::getStartDate));
        return responses;
    }

    @Transactional
    public CalendarEvent createEvent(String title, String description, LocalDate startDate, LocalDate endDate, String color) {
        CalendarEvent event = CalendarEvent.builder()
                .title(title)
                .description(description)
                .startDate(startDate)
                .endDate(endDate)
                .color(color)
                .build();
        return calendarEventRepository.save(event);
    }

    @Transactional
    public CalendarEvent updateEvent(Long id, String title, String description, LocalDate startDate, LocalDate endDate, String color) {
        CalendarEvent event = calendarEventRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 일정입니다."));
        event.setTitle(title);
        event.setDescription(description);
        event.setStartDate(startDate);
        event.setEndDate(endDate);
        if (color != null) {
            event.setColor(color);
        }
        return calendarEventRepository.save(event);
    }

    @Transactional
    public void deleteEvent(Long id) {
        CalendarEvent event = calendarEventRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 일정입니다."));
        calendarEventRepository.delete(event);
    }

    @Data
    @AllArgsConstructor
    public static class CalendarEventResponse {
        private Long id;
        private String title;
        private String description;
        private LocalDate startDate;
        private LocalDate endDate;
        private String type; // ACADEMIC, NOTICE
        private Long noticeId; // NOTICE 타입일 때의 Notice 엔티티 ID
        private String color;
    }
}
