package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeType;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 💡 공지 피드(커서 페이징)를 고정하는 테스트입니다.
 *
 * 이전에는 프론트가 `/notices`를 페이지 지정 없이 불러 기본 20건만 받았고 더 볼 방법이 없었습니다.
 * 즉 21번째 공지부터는 DB에 있어도 학생이 도달할 수 없었습니다.
 *
 * 테스트 DB는 스위트 전체가 공유하고 이 클래스는 @Transactional을 걸지 않으므로(커서 동작을
 * 실제 커밋된 행으로 확인해야 합니다) 다른 테스트가 만든 공지가 섞입니다.
 * 그래서 모든 조회에 이 클래스만의 표식을 keyword로 넘겨 대상 범위를 좁힙니다.
 */
@SpringBootTest
class NoticeFeedTest {

    @Autowired private NoticeService noticeService;
    @Autowired private NoticeRepository noticeRepository;
    @Autowired private MemberRepository memberRepository;
    @Autowired private JdbcTemplate jdbcTemplate;

    @MockitoBean private JavaMailSender javaMailSender;

    private Member author;
    private String marker;

    @BeforeEach
    void setUp() {
        author = memberRepository.save(Member.builder()
                .loginId("feed-" + System.nanoTime()).password("encoded").name("작성자")
                .role(MemberRole.ADMIN).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(true).isSuspended(false)
                .build());
        marker = "FEEDMARK" + System.nanoTime();
    }

    private Notice createNotice(int index, boolean pinned, Grade grade) {
        return noticeRepository.save(new Notice(
                marker + " 공지 " + index, "내용", author, NoticeType.NOTICE, null,
                grade, pinned, null, null));
    }

    /** 💡 created_at은 감사(auditing)가 넣으므로, 같은 시각을 재현하려면 직접 덮어써야 합니다. */
    private void forceCreatedAt(Notice notice, LocalDateTime createdAt) {
        jdbcTemplate.update("UPDATE notice SET created_at = ? WHERE id = ?", createdAt, notice.getId());
    }

    /** 커서를 끝까지 따라가며 받은 공지를 순서대로 모읍니다. */
    private List<Long> drainFeed(int size, Grade grade) {
        List<Long> collected = new ArrayList<>();
        String cursor = null;
        for (int guard = 0; guard < 100; guard++) {
            NoticeService.NoticeFeed feed = noticeService.getFeed(cursor, size, grade, marker);
            feed.items().forEach(notice -> collected.add(notice.getId()));
            if (!feed.hasNext()) {
                return collected;
            }
            cursor = feed.nextCursor();
        }
        throw new IllegalStateException("커서가 끝나지 않았습니다. 무한 루프 방지로 중단합니다.");
    }

    @Test
    void 커서로_끝까지_받으면_공지가_빠지거나_겹치지_않는다() {
        List<Long> expected = new ArrayList<>();
        for (int i = 0; i < 25; i++) {
            expected.add(createNotice(i, false, Grade.ALL).getId());
        }

        List<Long> collected = drainFeed(10, Grade.ALL);

        // 최신순이므로 생성 역순입니다.
        assertThat(collected).containsExactlyElementsOf(expected.reversed());
        assertThat(collected).doesNotHaveDuplicates();
    }

    @Test
    void 생성_시각이_같아도_커서가_행을_건너뛰지_않는다() {
        // 💡 created_at은 UNIQUE가 아닙니다. id를 tie-breaker로 쓰지 않으면 여기서 행이 새거나 겹칩니다.
        LocalDateTime sameMoment = LocalDateTime.of(2026, 3, 2, 9, 0, 0);
        List<Long> expected = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            Notice notice = createNotice(i, false, Grade.ALL);
            forceCreatedAt(notice, sameMoment);
            expected.add(notice.getId());
        }

        List<Long> collected = drainFeed(2, Grade.ALL);

        assertThat(collected).containsExactlyElementsOf(expected.reversed());
    }

    @Test
    void 고정_공지는_첫_페이지에만_오고_커서_페이지에는_오지_않는다() {
        Notice pinned = createNotice(0, true, Grade.ALL);
        for (int i = 1; i <= 12; i++) {
            createNotice(i, false, Grade.ALL);
        }

        NoticeService.NoticeFeed first = noticeService.getFeed(null, 10, Grade.ALL, marker);
        assertThat(first.pinned()).extracting(Notice::getId).containsExactly(pinned.getId());
        assertThat(first.items()).extracting(Notice::getId).doesNotContain(pinned.getId());
        assertThat(first.hasNext()).isTrue();

        NoticeService.NoticeFeed second = noticeService.getFeed(first.nextCursor(), 10, Grade.ALL, marker);
        assertThat(second.pinned()).isEmpty();
        assertThat(second.items()).extracting(Notice::getId).doesNotContain(pinned.getId());
        assertThat(second.hasNext()).isFalse();
        assertThat(second.nextCursor()).isNull();
    }

    @Test
    void 학년_필터는_전체_공지와_해당_학년만_준다() {
        // 💡 프론트가 하던 `targetGrade == 'ALL' || targetGrade == selected`와 결과가 같아야 합니다.
        Notice all = createNotice(0, false, Grade.ALL);
        Notice first = createNotice(1, false, Grade.GRADE_1);
        Notice second = createNotice(2, false, Grade.GRADE_2);

        assertThat(noticeService.getFeed(null, 10, Grade.GRADE_1, marker).items())
                .extracting(Notice::getId)
                .containsExactlyInAnyOrder(all.getId(), first.getId());

        assertThat(noticeService.getFeed(null, 10, Grade.ALL, marker).items())
                .extracting(Notice::getId)
                .containsExactlyInAnyOrder(all.getId(), first.getId(), second.getId());
    }

    @Test
    void 한_페이지에_다_들어가면_다음_커서가_없다() {
        createNotice(0, false, Grade.ALL);
        createNotice(1, false, Grade.ALL);

        NoticeService.NoticeFeed feed = noticeService.getFeed(null, 10, Grade.ALL, marker);

        assertThat(feed.items()).hasSize(2);
        assertThat(feed.hasNext()).isFalse();
        assertThat(feed.nextCursor()).isNull();
    }

    @Test
    void size는_상한을_넘지_않고_잘못된_값은_기본값을_쓴다() {
        for (int i = 0; i < 40; i++) {
            createNotice(i, false, Grade.ALL);
        }

        assertThat(noticeService.getFeed(null, 1000, Grade.ALL, marker).items())
                .hasSize(NoticeService.FEED_MAX_SIZE);
        assertThat(noticeService.getFeed(null, 0, Grade.ALL, marker).items())
                .hasSize(NoticeService.FEED_DEFAULT_SIZE);
        assertThat(noticeService.getFeed(null, null, Grade.ALL, marker).items())
                .hasSize(NoticeService.FEED_DEFAULT_SIZE);
    }

    @Test
    void 깨진_커서는_거부한다() {
        // 조용히 첫 페이지로 돌아가면 "왜 목록이 처음으로 갔는지" 알 수 없으므로 드러냅니다.
        assertThatThrownBy(() -> noticeService.getFeed("not-a-cursor!!", 10, Grade.ALL, marker))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("커서");
    }

    @Test
    void 새_공지_수는_latestId_이후만_세고_고정_공지도_포함한다() {
        createNotice(0, false, Grade.ALL);
        Long latestId = noticeService.getFeed(null, 10, Grade.ALL, marker).latestId();

        assertThat(noticeService.countNewNotices(latestId, Grade.ALL, marker)).isZero();

        createNotice(1, false, Grade.ALL);
        createNotice(2, true, Grade.ALL); // 스크롤 도중 올라온 고정 공지도 사용자에겐 새 공지입니다.

        assertThat(noticeService.countNewNotices(latestId, Grade.ALL, marker)).isEqualTo(2);
        // 기준값이 없으면 셀 수 없습니다.
        assertThat(noticeService.countNewNotices(null, Grade.ALL, marker)).isZero();
    }

    @Test
    void 새_공지_수는_상한에서_멈춘다() {
        createNotice(0, false, Grade.ALL);
        Long latestId = noticeService.getFeed(null, 10, Grade.ALL, marker).latestId();
        for (int i = 1; i <= NoticeService.NEW_NOTICE_COUNT_CAP + 5; i++) {
            createNotice(i, false, Grade.ALL);
        }

        assertThat(noticeService.countNewNotices(latestId, Grade.ALL, marker))
                .isEqualTo(NoticeService.NEW_NOTICE_COUNT_CAP);
    }
}
