package com.ync.ysync.service;

import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.TimetableEntry;
import com.ync.ysync.repository.TimetableEntryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TimetableService {

    private final TimetableEntryRepository timetableEntryRepository;

    // 💡 학년별 시간표 조회
    public List<TimetableEntry> getTimetable(Grade grade) {
        if (grade == null) {
            throw new IllegalArgumentException("조회할 학년이 지정되지 않았습니다.");
        }
        return timetableEntryRepository.findAllByGrade(grade);
    }

    // 💡 단일 시간표 항목 등록 (중복/겹침 방지 로직 적용)
    @Transactional
    public TimetableEntry createTimetableEntry(Grade grade, DayOfWeek dayOfWeek, String subjectName, String professorName, String classroom, int startPeriod, int endPeriod) {
        validatePeriods(startPeriod, endPeriod);

        // 시간표 겹침 검증 (Double-booking 방지)
        if (timetableEntryRepository.existsOverlapping(grade, dayOfWeek, startPeriod, endPeriod)) {
            throw new IllegalArgumentException(String.format("시간표 등록 실패: 해당 학년(%s), 요일(%s)의 %d~%d교시에 이미 등록된 수업이 존재합니다.", 
                    grade.name(), dayOfWeek.name(), startPeriod, endPeriod));
        }

        TimetableEntry entry = TimetableEntry.builder()
                .grade(grade)
                .dayOfWeek(dayOfWeek)
                .subjectName(subjectName)
                .professorName(professorName)
                .classroom(classroom)
                .startPeriod(startPeriod)
                .endPeriod(endPeriod)
                .build();

        return timetableEntryRepository.save(entry);
    }

    // 💡 단일 시간표 항목 수정 (본인 ID 제외 겹침 검증)
    @Transactional
    public TimetableEntry updateTimetableEntry(Long id, Grade grade, DayOfWeek dayOfWeek, String subjectName, String professorName, String classroom, int startPeriod, int endPeriod) {
        TimetableEntry entry = timetableEntryRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 시간표 항목입니다."));

        validatePeriods(startPeriod, endPeriod);

        // 본인 항목을 제외하고 시간표가 겹치는지 확인
        if (timetableEntryRepository.existsOverlappingWithExclude(grade, dayOfWeek, startPeriod, endPeriod, id)) {
            throw new IllegalArgumentException(String.format("시간표 수정 실패: 변경하려는 %d~%d교시에 이미 다른 수업이 겹쳐 있습니다.", 
                    startPeriod, endPeriod));
        }

        entry.setGrade(grade);
        entry.setDayOfWeek(dayOfWeek);
        entry.setSubjectName(subjectName);
        entry.setProfessorName(professorName);
        entry.setClassroom(classroom);
        entry.setStartPeriod(startPeriod);
        entry.setEndPeriod(endPeriod);

        return timetableEntryRepository.save(entry);
    }

    // 💡 시간표 삭제
    @Transactional
    public void deleteTimetableEntry(Long id) {
        TimetableEntry entry = timetableEntryRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 시간표 항목입니다."));
        timetableEntryRepository.delete(entry);
    }

    private void validatePeriods(int startPeriod, int endPeriod) {
        if (startPeriod < 1 || startPeriod > 9 || endPeriod < 1 || endPeriod > 9) {
            throw new IllegalArgumentException("교시는 1교시부터 9교시 사이여야 합니다.");
        }
        if (startPeriod > endPeriod) {
            throw new IllegalArgumentException("시작 교시는 종료 교시보다 작거나 같아야 합니다.");
        }
    }
}
