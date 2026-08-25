package com.ync.ysync.controller;

import com.ync.ysync.config.AuthUtil;
import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.PersonalTimetableEntry;
import com.ync.ysync.domain.TimetableEntry;
import com.ync.ysync.service.PersonalTimetableService;
import com.ync.ysync.service.TimetableService;
import io.swagger.v3.oas.annotations.Operation;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.DayOfWeek;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/timetable")
@RequiredArgsConstructor
public class TimetableController {

    private final TimetableService timetableService;
    private final PersonalTimetableService personalTimetableService;
    private final AuthUtil authUtil;

    @Operation(summary = "개인 시간표 조회", description = "로그인한 사용자가 직접 등록한 개인 시간표를 조회합니다.")
    @GetMapping("/personal")
    public ResponseEntity<List<PersonalTimetableResponse>> getPersonalTimetable() {
        return ResponseEntity.ok(personalTimetableService.getEntries(requiredMemberId())
                .stream()
                .map(PersonalTimetableResponse::from)
                .toList());
    }

    @Operation(summary = "개인 시간표 추가", description = "로그인한 사용자의 개인 시간표에 수업을 추가합니다.")
    @PostMapping("/personal")
    public ResponseEntity<PersonalTimetableResponse> createPersonalTimetableEntry(
            @Valid @RequestBody PersonalTimetableRequest request) {
        PersonalTimetableEntry entry = personalTimetableService.createEntry(
                requiredMemberId(),
                request.getDayOfWeek(),
                request.getSubjectName(),
                request.getProfessorName(),
                request.getClassroom(),
                request.getStartPeriod(),
                request.getEndPeriod()
        );
        return ResponseEntity.ok(PersonalTimetableResponse.from(entry));
    }

    @Operation(summary = "개인 시간표 수정", description = "로그인한 사용자가 소유한 개인 시간표 수업을 수정합니다.")
    @PutMapping("/personal/{id}")
    public ResponseEntity<PersonalTimetableResponse> updatePersonalTimetableEntry(
            @PathVariable Long id,
            @Valid @RequestBody PersonalTimetableRequest request) {
        PersonalTimetableEntry entry = personalTimetableService.updateEntry(
                id,
                requiredMemberId(),
                request.getDayOfWeek(),
                request.getSubjectName(),
                request.getProfessorName(),
                request.getClassroom(),
                request.getStartPeriod(),
                request.getEndPeriod()
        );
        return ResponseEntity.ok(PersonalTimetableResponse.from(entry));
    }

    @Operation(summary = "개인 시간표 삭제", description = "로그인한 사용자가 소유한 개인 시간표 수업을 삭제합니다.")
    @DeleteMapping("/personal/{id}")
    public ResponseEntity<Map<String, String>> deletePersonalTimetableEntry(@PathVariable Long id) {
        personalTimetableService.deleteEntry(id, requiredMemberId());
        return ResponseEntity.ok(Map.of("message", "개인 시간표 수업이 삭제되었습니다."));
    }

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

    @Data
    public static class PersonalTimetableRequest {
        @NotNull(message = "요일을 선택해 주세요.")
        private DayOfWeek dayOfWeek;

        @NotBlank(message = "과목명을 입력해 주세요.")
        @Size(max = 100, message = "과목명은 100자 이하로 입력해 주세요.")
        private String subjectName;

        @Size(max = 100, message = "담당 교수는 100자 이하로 입력해 주세요.")
        private String professorName;

        @Size(max = 100, message = "강의실은 100자 이하로 입력해 주세요.")
        private String classroom;

        @Min(value = 1, message = "시작 교시는 1교시 이상이어야 합니다.")
        @Max(value = 9, message = "시작 교시는 9교시 이하여야 합니다.")
        private int startPeriod;

        @Min(value = 1, message = "종료 교시는 1교시 이상이어야 합니다.")
        @Max(value = 9, message = "종료 교시는 9교시 이하여야 합니다.")
        private int endPeriod;
    }

    @Getter
    @AllArgsConstructor
    public static class PersonalTimetableResponse {
        private Long id;
        private DayOfWeek dayOfWeek;
        private String subjectName;
        private String professorName;
        private String classroom;
        private int startPeriod;
        private int endPeriod;

        public static PersonalTimetableResponse from(PersonalTimetableEntry entry) {
            return new PersonalTimetableResponse(
                    entry.getId(),
                    entry.getDayOfWeek(),
                    entry.getSubjectName(),
                    entry.getProfessorName(),
                    entry.getClassroom(),
                    entry.getStartPeriod(),
                    entry.getEndPeriod()
            );
        }
    }

    private Long requiredMemberId() {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) {
            throw new IllegalArgumentException("로그인이 필요합니다.");
        }
        return memberId;
    }
}
