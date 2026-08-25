package com.ync.ysync.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.DayOfWeek;

@Entity
@Table(
        name = "personal_timetable_entry",
        indexes = @Index(name = "idx_personal_timetable_member", columnList = "member_id")
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PersonalTimetableEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Setter
    private DayOfWeek dayOfWeek;

    @Column(nullable = false, length = 100)
    @Setter
    private String subjectName;

    @Column(nullable = false, length = 100)
    @Setter
    private String professorName;

    @Column(nullable = false, length = 100)
    @Setter
    private String classroom;

    @Column(nullable = false)
    @Setter
    private int startPeriod;

    @Column(nullable = false)
    @Setter
    private int endPeriod;

    @Builder
    public PersonalTimetableEntry(
            Member member,
            DayOfWeek dayOfWeek,
            String subjectName,
            String professorName,
            String classroom,
            int startPeriod,
            int endPeriod) {
        this.member = member;
        this.dayOfWeek = dayOfWeek;
        this.subjectName = subjectName;
        this.professorName = professorName;
        this.classroom = classroom;
        this.startPeriod = startPeriod;
        this.endPeriod = endPeriod;
    }
}
