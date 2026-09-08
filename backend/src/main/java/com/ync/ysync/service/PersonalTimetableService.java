package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.PersonalTimetableEntry;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.PersonalTimetableEntryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

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
    public List<PersonalTimetableEntry> createEntries(
            Long memberId,
            List<EntryDraft> drafts) {
        if (drafts == null || drafts.isEmpty()) {
            throw new IllegalArgumentException("추가할 수업을 선택해 주세요.");
        }
        if (drafts.size() > 50) {
            throw new IllegalArgumentException("수업은 한 번에 50개까지 추가할 수 있습니다.");
        }

        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원 정보를 찾을 수 없습니다."));
        Set<String> occupiedPeriods = new HashSet<>();
        for (PersonalTimetableEntry entry : personalTimetableEntryRepository.findAllByMemberId(memberId)) {
            addOccupiedPeriods(occupiedPeriods, entry.getDayOfWeek(), entry.getStartPeriod(), entry.getEndPeriod());
        }

        List<PersonalTimetableEntry> entries = drafts.stream().map(draft -> {
            validate(draft.dayOfWeek(), draft.subjectName(), draft.startPeriod(), draft.endPeriod());
            for (int period = draft.startPeriod(); period <= draft.endPeriod(); period++) {
                if (!occupiedPeriods.add(draft.dayOfWeek() + ":" + period)) {
                    throw new IllegalArgumentException(
                            String.format("%s %d~%d교시에 이미 다른 수업이 있습니다.",
                                    draft.dayOfWeek(), draft.startPeriod(), draft.endPeriod()));
                }
            }
            return PersonalTimetableEntry.builder()
                    .member(member)
                    .dayOfWeek(draft.dayOfWeek())
                    .subjectName(draft.subjectName().trim())
                    .professorName(normalizeOptional(draft.professorName(), "교수명"))
                    .classroom(normalizeOptional(draft.classroom(), "강의실"))
                    .startPeriod(draft.startPeriod())
                    .endPeriod(draft.endPeriod())
                    .build();
        }).toList();
        return personalTimetableEntryRepository.saveAll(entries);
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
        if (dayOfWeek == null || dayOfWeek.getValue() > DayOfWeek.SATURDAY.getValue()) {
            throw new IllegalArgumentException("개인 시간표는 월요일부터 토요일까지만 등록할 수 있습니다.");
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

    private void addOccupiedPeriods(Set<String> occupiedPeriods, DayOfWeek dayOfWeek, int startPeriod, int endPeriod) {
        for (int period = startPeriod; period <= endPeriod; period++) {
            occupiedPeriods.add(dayOfWeek + ":" + period);
        }
    }

    public record EntryDraft(
            DayOfWeek dayOfWeek,
            String subjectName,
            String professorName,
            String classroom,
            int startPeriod,
            int endPeriod) {
    }
}
