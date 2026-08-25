package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.PersonalTimetableEntry;
import com.ync.ysync.repository.MemberRepository;
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
class PersonalTimetableServiceIntegrationTest {

    @Autowired
    private PersonalTimetableService personalTimetableService;

    @Autowired
    private MemberRepository memberRepository;

    @MockitoBean
    private JavaMailSender mailSender;

    @Test
    void keepsEntriesPerMemberAndRejectsOnlyTheOwnersOverlap() {
        Member firstMember = saveMember("personal-timetable-first");
        Member secondMember = saveMember("personal-timetable-second");

        personalTimetableService.createEntry(
                firstMember.getId(), DayOfWeek.MONDAY, "모바일", "김교수", "301호", 1, 2);
        personalTimetableService.createEntry(
                secondMember.getId(), DayOfWeek.MONDAY, "데이터베이스", "이교수", "401호", 1, 2);

        assertEquals(1, personalTimetableService.getEntries(firstMember.getId()).size());
        assertEquals(1, personalTimetableService.getEntries(secondMember.getId()).size());
        assertThrows(IllegalArgumentException.class, () -> personalTimetableService.createEntry(
                firstMember.getId(), DayOfWeek.MONDAY, "겹치는 수업", "", "", 2, 3));
    }

    @Test
    void preventsAnotherMemberFromUpdatingOrDeletingAnEntry() {
        Member owner = saveMember("personal-timetable-owner");
        Member otherMember = saveMember("personal-timetable-other");
        PersonalTimetableEntry entry = personalTimetableService.createEntry(
                owner.getId(), DayOfWeek.TUESDAY, "운영체제", "박교수", "201호", 3, 4);

        assertThrows(IllegalArgumentException.class, () -> personalTimetableService.updateEntry(
                entry.getId(), otherMember.getId(), DayOfWeek.WEDNESDAY,
                "변경 시도", "", "", 1, 1));
        assertThrows(IllegalArgumentException.class, () ->
                personalTimetableService.deleteEntry(entry.getId(), otherMember.getId()));
        assertEquals(1, personalTimetableService.getEntries(owner.getId()).size());
    }

    private Member saveMember(String loginId) {
        return memberRepository.save(Member.builder()
                .loginId(loginId)
                .password("encoded-password")
                .name(loginId)
                .role(MemberRole.USER)
                .isActivated(true)
                .build());
    }
}
