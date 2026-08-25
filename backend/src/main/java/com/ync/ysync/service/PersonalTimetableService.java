package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.PersonalTimetableEntry;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.PersonalTimetableEntryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PersonalTimetableService {

    private final PersonalTimetableEntryRepository personalTimetableEntryRepository;
    private final MemberRepository memberRepository;

    public List<PersonalTimetableEntry> getEntries(Long memberId) {
        return personalTimetableEntryRepository.findAllByMemberId(memberId);
    }

    @Transactional
    public PersonalTimetableEntry createEntry(
            Long memberId,
            DayOfWeek dayOfWeek,
            String subjectName,
            String professorName,
            String classroom,
            int startPeriod,
            int endPeriod) {
        validate(dayOfWeek, subjectName, startPeriod, endPeriod);
        if (personalTimetableEntryRepository.existsOverlapping(
                memberId, dayOfWeek, startPeriod, endPeriod)) {
            throw new IllegalArgumentException("같은 시간에 이미 등록된 개인 수업이 있습니다.");
        }

        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원 정보를 찾을 수 없습니다."));

        return personalTimetableEntryRepository.save(PersonalTimetableEntry.builder()
                .member(member)
                .dayOfWeek(dayOfWeek)
                .subjectName(subjectName.trim())
                .professorName(normalizeOptional(professorName, "교수명"))
                .classroom(normalizeOptional(classroom, "강의실"))
                .startPeriod(startPeriod)
                .endPeriod(endPeriod)
                .build());
    }

    @Transactional
    public PersonalTimetableEntry updateEntry(
            Long id,
            Long memberId,
            DayOfWeek dayOfWeek,
            String subjectName,
            String professorName,
            String classroom,
            int startPeriod,
            int endPeriod) {
        validate(dayOfWeek, subjectName, startPeriod, endPeriod);
        PersonalTimetableEntry entry = getOwnedEntry(id, memberId);

        if (personalTimetableEntryRepository.existsOverlappingWithExclude(
                memberId, dayOfWeek, startPeriod, endPeriod, id)) {
            throw new IllegalArgumentException("같은 시간에 이미 등록된 개인 수업이 있습니다.");
        }

        entry.setDayOfWeek(dayOfWeek);
        entry.setSubjectName(subjectName.trim());
        entry.setProfessorName(normalizeOptional(professorName, "교수명"));
        entry.setClassroom(normalizeOptional(classroom, "강의실"));
        entry.setStartPeriod(startPeriod);
        entry.setEndPeriod(endPeriod);
        return personalTimetableEntryRepository.save(entry);
    }

    @Transactional
    public void deleteEntry(Long id, Long memberId) {
        personalTimetableEntryRepository.delete(getOwnedEntry(id, memberId));
    }

    private PersonalTimetableEntry getOwnedEntry(Long id, Long memberId) {
        return personalTimetableEntryRepository.findByIdAndMemberId(id, memberId)
                .orElseThrow(() -> new IllegalArgumentException("개인 시간표 항목을 찾을 수 없습니다."));
    }

    private void validate(DayOfWeek dayOfWeek, String subjectName, int startPeriod, int endPeriod) {
        if (dayOfWeek == null || dayOfWeek.getValue() > DayOfWeek.FRIDAY.getValue()) {
            throw new IllegalArgumentException("개인 시간표는 월요일부터 금요일까지만 등록할 수 있습니다.");
        }
        if (subjectName == null || subjectName.trim().isEmpty()) {
            throw new IllegalArgumentException("과목명을 입력해 주세요.");
        }
        if (subjectName.trim().length() > 100) {
            throw new IllegalArgumentException("과목명은 100자 이하로 입력해 주세요.");
        }
        if (startPeriod < 1 || startPeriod > 9 || endPeriod < 1 || endPeriod > 9) {
            throw new IllegalArgumentException("교시는 1교시부터 9교시 사이여야 합니다.");
        }
        if (startPeriod > endPeriod) {
            throw new IllegalArgumentException("시작 교시는 종료 교시보다 작거나 같아야 합니다.");
        }
    }

    private String normalizeOptional(String value, String fieldName) {
        String normalized = value == null ? "" : value.trim();
        if (normalized.length() > 100) {
            throw new IllegalArgumentException(fieldName + "은 100자 이하로 입력해 주세요.");
        }
        return normalized;
    }
}
