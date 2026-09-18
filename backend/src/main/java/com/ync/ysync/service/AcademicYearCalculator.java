package com.ync.ysync.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.LocalDate;
import java.time.MonthDay;
import java.time.ZoneId;

/**
 * 💡 학년도를 서버에서 계산합니다.
 *
 * 기준일은 매년 3월 1일 00:00 (Asia/Seoul)입니다. 3월부터 12월까지는 현재 연도가 학년도이고,
 * 1월과 2월은 이전 연도가 학년도입니다. 학기와 학년도는 구분하므로 2학기 시작은 학년도를 바꾸지 않습니다.
 *
 * 단말기 시각이 틀려도 결과가 달라지지 않도록 클라이언트가 아닌 서버가 계산합니다.
 * 학교의 학년도 기준일이 다르면 출시 전에 아래 설정으로 조정합니다.
 */
@Component
public class AcademicYearCalculator {

    public static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    private final MonthDay cutover;
    private final Clock clock;

    @Autowired
    public AcademicYearCalculator(
            @Value("${ysync.academic-year.cutover-month:3}") int cutoverMonth,
            @Value("${ysync.academic-year.cutover-day:1}") int cutoverDay) {
        this(MonthDay.of(cutoverMonth, cutoverDay), Clock.system(SEOUL));
    }

    // 테스트에서 임의 시점을 고정하기 위한 생성자입니다.
    AcademicYearCalculator(MonthDay cutover, Clock clock) {
        this.cutover = cutover;
        this.clock = clock;
    }

    /** 지금 시점(Asia/Seoul)의 학년도입니다. */
    public int currentAcademicYear() {
        return academicYearOf(LocalDate.now(clock));
    }

    /** 특정 날짜가 속한 학년도입니다. 기준일 이전이면 이전 연도가 됩니다. */
    public int academicYearOf(LocalDate date) {
        return MonthDay.from(date).isBefore(cutover) ? date.getYear() - 1 : date.getYear();
    }
}
