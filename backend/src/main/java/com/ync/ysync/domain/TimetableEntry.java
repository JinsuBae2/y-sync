package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.DayOfWeek;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TimetableEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Setter
    private Grade grade;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Setter
    private DayOfWeek dayOfWeek;

    @Column(nullable = false)
    @Setter
    private String subjectName;

    @Column(nullable = false)
    @Setter
    private String professorName;

    @Column(nullable = false)
    @Setter
    private String classroom;

    @Column(nullable = false)
    @Setter
    private int startPeriod;

    @Column(nullable = false)
    @Setter
    private int endPeriod;

    @Builder
    public TimetableEntry(Grade grade, DayOfWeek dayOfWeek, String subjectName, String professorName, String classroom, int startPeriod, int endPeriod) {
        this.grade = grade;
        this.dayOfWeek = dayOfWeek;
        this.subjectName = subjectName;
        this.professorName = professorName;
        this.classroom = classroom;
        this.startPeriod = startPeriod;
        this.endPeriod = endPeriod;
    }
}
