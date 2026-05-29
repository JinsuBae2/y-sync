package com.ync.ysync.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CalendarEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    @Setter
    private String title;

    @Column(columnDefinition = "TEXT")
    @Setter
    private String description;

    @Column(nullable = false)
    @Setter
    private LocalDate startDate;

    @Column(nullable = false)
    @Setter
    private LocalDate endDate;

    @Setter
    private String color;

    @Builder
    public CalendarEvent(String title, String description, LocalDate startDate, LocalDate endDate, String color) {
        this.title = title;
        this.description = description;
        this.startDate = startDate;
        this.endDate = endDate;
        this.color = color != null ? color : "#4A90E2"; // 기본 푸른빛 계열 색상
    }
}
