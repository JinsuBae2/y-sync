package com.ync.ysync.controller;

import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.TimetableEntry;
import com.ync.ysync.service.TimetableService;
import io.swagger.v3.oas.annotations.Operation;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.DayOfWeek;
import java.util.List;

@RestController
@RequestMapping("/api/v1/timetable")
@RequiredArgsConstructor
public class TimetableController {

    private final TimetableService timetableService;

    @Operation(summary = "학년별 학과 시간표 조회", description = "특정 학년의 시간표 목록을 조회합니다.")
    @GetMapping("/{grade}")
    public ResponseEntity<List<TimetableEntry>> getTimetable(@PathVariable Grade grade) {
        return ResponseEntity.ok(timetableService.getTimetable(grade));
    }

    @Operation(summary = "시간표 항목 추가 (관리자)", description = "관리자가 특정 학년의 시간표 항목을 추가합니다. 동일 교시 겹침 방지 검증을 거칩니다.")
    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<TimetableEntry> createTimetableEntry(@RequestBody TimetableRequest request) {
        TimetableEntry entry = timetableService.createTimetableEntry(
                request.getGrade(),
                request.getDayOfWeek(),
                request.getSubjectName(),
                request.getProfessorName(),
                request.getClassroom(),
                request.getStartPeriod(),
                request.getEndPeriod()
        );
        return ResponseEntity.ok(entry);
    }

    @Operation(summary = "시간표 항목 수정 (관리자)", description = "관리자가 기존 시간표 항목을 수정합니다. 본인을 제외한 겹침 검증을 수행합니다.")
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<TimetableEntry> updateTimetableEntry(
            @PathVariable Long id,
            @RequestBody TimetableRequest request) {
        TimetableEntry entry = timetableService.updateTimetableEntry(
                id,
                request.getGrade(),
                request.getDayOfWeek(),
                request.getSubjectName(),
                request.getProfessorName(),
                request.getClassroom(),
                request.getStartPeriod(),
                request.getEndPeriod()
        );
        return ResponseEntity.ok(entry);
    }

    @Operation(summary = "시간표 항목 삭제 (관리자)", description = "관리자가 시간표 항목을 삭제합니다.")
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<String> deleteTimetableEntry(@PathVariable Long id) {
        timetableService.deleteTimetableEntry(id);
        return ResponseEntity.ok("시간표 삭제 성공");
    }

    @Data
    public static class TimetableRequest {
        private Grade grade;
        private DayOfWeek dayOfWeek;
        private String subjectName;
        private String professorName;
        private String classroom;
        private int startPeriod;
        private int endPeriod;
    }
}
