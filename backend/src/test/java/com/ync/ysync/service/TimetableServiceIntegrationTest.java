package com.ync.ysync.service;

import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.TimetableEntry;
import com.ync.ysync.repository.TimetableEntryRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

@SpringBootTest
@Transactional
class TimetableServiceIntegrationTest {

    @Autowired
    private TimetableService timetableService;

    @Autowired
    private TimetableEntryRepository timetableEntryRepository;

    @MockitoBean
    private JavaMailSender mailSender;

    @Test
    void allowsSamePeriodForDifferentClassesAndFiltersByClass() {
        timetableEntryRepository.deleteAll();

        timetableService.createTimetableEntry(
                Grade.GRADE_1, 1, DayOfWeek.MONDAY,
                "파이썬응용", "조정현", "모바일소프트웨어실습실", 1, 3);
        timetableService.createTimetableEntry(
                Grade.GRADE_1, 2, DayOfWeek.MONDAY,
                "C기초", "이명섭", "데이터베이스실습실", 1, 3);

        assertEquals("파이썬응용", timetableService.getTimetable(Grade.GRADE_1, 1).getFirst().getSubjectName());
        assertEquals("C기초", timetableService.getTimetable(Grade.GRADE_1, 2).getFirst().getSubjectName());
    }

    @Test
    void rejectsClassOutsideGradeRange() {
        assertThrows(IllegalArgumentException.class, () ->
                timetableService.getTimetable(Grade.GRADE_1, 3));
    }
}
