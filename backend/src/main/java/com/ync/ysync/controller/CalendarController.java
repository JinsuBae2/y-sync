package com.ync.ysync.controller;

  import com.ync.ysync.domain.CalendarEvent;
  import com.ync.ysync.service.CalendarService;
  import com.ync.ysync.service.CalendarService.CalendarEventResponse;
  import io.swagger.v3.oas.annotations.Operation;
  import lombok.Data;
  import lombok.RequiredArgsConstructor;
  import org.springframework.format.annotation.DateTimeFormat;
  import org.springframework.http.ResponseEntity;
  import org.springframework.security.access.prepost.PreAuthorize;
  import org.springframework.web.bind.annotation.*;

  import java.time.LocalDate;
  import java.util.List;

  @RestController
  @RequestMapping("/api/v1/calendar")
  @RequiredArgsConstructor
  public class CalendarController {

      private final CalendarService calendarService;

      @Operation(summary = "학사 일정 조회", description = "특정 기간의 학사 일정 및 일정이 등록된 공지사항을 통합 조회합니다.")
      @GetMapping
      public ResponseEntity<List<CalendarEventResponse>> getEvents(
              @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
              @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
          return ResponseEntity.ok(calendarService.getEvents(startDate, endDate));
      }

      @Operation(summary = "학사 일정 추가 (관리자)", description = "관리자가 일반 학사 일정을 추가합니다.")
      @PostMapping
      @PreAuthorize("hasRole('ADMIN')")
      public ResponseEntity<CalendarEvent> createEvent(@RequestBody EventRequest request) {
          CalendarEvent event = calendarService.createEvent(
                  request.getTitle(),
                  request.getDescription(),
                  request.getStartDate(),
                  request.getEndDate(),
                  request.getColor()
          );
          return ResponseEntity.ok(event);
      }

      @Operation(summary = "학사 일정 수정 (관리자)", description = "관리자가 일반 학사 일정을 수정합니다.")
      @PutMapping("/{id}")
      @PreAuthorize("hasRole('ADMIN')")
      public ResponseEntity<CalendarEvent> updateEvent(
              @PathVariable Long id,
              @RequestBody EventRequest request) {
          CalendarEvent event = calendarService.updateEvent(
                  id,
                  request.getTitle(),
                  request.getDescription(),
                  request.getStartDate(),
                  request.getEndDate(),
                  request.getColor()
          );
          return ResponseEntity.ok(event);
      }

      @Operation(summary = "학사 일정 삭제 (관리자)", description = "관리자가 일반 학사 일정을 삭제합니다.")
      @DeleteMapping("/{id}")
      @PreAuthorize("hasRole('ADMIN')")
      public ResponseEntity<String> deleteEvent(@PathVariable Long id) {
          calendarService.deleteEvent(id);
          return ResponseEntity.ok("일정 삭제 성공");
      }

      @Data
      public static class EventRequest {
          private String title;
          private String description;
          private LocalDate startDate;
          private LocalDate endDate;
          private String color;
      }
  }
