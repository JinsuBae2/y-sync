package com.ync.ysync.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import java.time.Clock;
import java.time.LocalDate;
import java.time.MonthDay;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 💡 학년도 계산 규칙을 고정하는 테스트입니다.
 *
 * 기준일은 3월 1일 00:00 (Asia/Seoul)이며, 1~2월은 이전 연도가 학년도입니다.
 * 2학기 시작(9월)은 학년도를 바꾸지 않아야 하고, 윤년 2월 29일도 같은 규칙을 따라야 합니다.
 */
class AcademicYearCalculatorTest {

    private final AcademicYearCalculator calculator =
            new AcademicYearCalculator(MonthDay.of(3, 1), Clock.systemUTC());

    @ParameterizedTest(name = "{0} → {1}학년도")
    @CsvSource({
            "2027-02-28, 2026",
            "2027-03-01, 2027",
            "2027-09-01, 2027",
            "2027-12-31, 2027",
            "2028-01-01, 2027",
            "2028-02-29, 2027",
            "2028-03-01, 2028",
    })
    void 기준일_전후로_학년도가_갈린다(String date, int expected) {
        assertThat(calculator.academicYearOf(LocalDate.parse(date))).isEqualTo(expected);
    }

    @Test
    void 이학기_시작만으로는_학년도가_오르지_않는다() {
        assertThat(calculator.academicYearOf(LocalDate.of(2027, 3, 1)))
                .isEqualTo(calculator.academicYearOf(LocalDate.of(2027, 9, 1)));
    }

    @Test
    void 기준일은_한국_시간을_따른다() {
        // UTC로 2027-02-28 15:00은 한국 시간으로 2027-03-01 00:00이다.
        Clock utcJustBeforeSeoulCutover = Clock.fixed(
                ZonedDateTime.of(2027, 2, 28, 15, 0, 0, 0, ZoneId.of("UTC")).toInstant(),
                AcademicYearCalculator.SEOUL);

        AcademicYearCalculator seoulCalculator =
                new AcademicYearCalculator(MonthDay.of(3, 1), utcJustBeforeSeoulCutover);

        assertThat(seoulCalculator.currentAcademicYear()).isEqualTo(2027);
    }

    @Test
    void 기준일은_학교_정책에_맞춰_조정할_수_있다() {
        AcademicYearCalculator marchSecond =
                new AcademicYearCalculator(MonthDay.of(3, 2), Clock.systemUTC());

        assertThat(marchSecond.academicYearOf(LocalDate.of(2027, 3, 1))).isEqualTo(2026);
        assertThat(marchSecond.academicYearOf(LocalDate.of(2027, 3, 2))).isEqualTo(2027);
    }
}
