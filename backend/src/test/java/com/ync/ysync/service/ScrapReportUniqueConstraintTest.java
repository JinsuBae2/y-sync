package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeType;
import com.ync.ysync.domain.Report;
import com.ync.ysync.domain.Scrap;
import com.ync.ysync.domain.TargetType;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository;
import com.ync.ysync.repository.ReportRepository;
import com.ync.ysync.repository.ScrapRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.IncorrectResultSizeDataAccessException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 💡 스크랩·신고의 중복행을 DB 제약(uq_scrap, uq_report)이 막는지 고정하는 테스트입니다.
 *
 * 두 서비스 모두 "조회 후 INSERT" 구조라 애플리케이션 검사만으로는 동시 요청을 막지 못합니다.
 * 중복행이 한 번 생기면 스크랩은 조회 자체가 IncorrectResultSizeDataAccessException으로 영구히 실패하고,
 * 신고는 한 사람의 신고가 여러 건으로 세어져 자동 블라인드 임계(5회)가 실제보다 적은 인원으로 도달합니다.
 *
 * 경쟁 상황을 실제 커밋으로 재현해야 하므로 클래스에 @Transactional을 걸지 않습니다.
 */
@SpringBootTest
class ScrapReportUniqueConstraintTest {

    @Autowired private ScrapService scrapService;
    @Autowired private ReportService reportService;
    @Autowired private ScrapRepository scrapRepository;
    @Autowired private ReportRepository reportRepository;
    @Autowired private MemberRepository memberRepository;
    @Autowired private NoticeRepository noticeRepository;
    @Autowired private CommunityPostRepository communityPostRepository;

    @MockitoBean private JavaMailSender javaMailSender;

    private Member createMember(String prefix) {
        return memberRepository.save(Member.builder()
                .loginId(prefix + "-" + System.nanoTime()).password("encoded").name("사용자")
                .role(MemberRole.USER).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(true).isSuspended(false)
                .build());
    }

    private Notice createNotice(Member author) {
        return noticeRepository.save(new Notice(
                "제약 테스트", "내용", author, NoticeType.NOTICE, null, Grade.ALL, false, null, null));
    }

    private CommunityPost createPost(Member author) {
        return communityPostRepository.save(CommunityPost.builder()
                .category("FREE").title("제약 테스트").content("내용")
                .anonymous(false).member(author).targetGrade(Grade.ALL).isPinned(false)
                .build());
    }

    @Test
    void 같은_대상에_대한_중복_스크랩_행은_DB가_거부한다() {
        Member member = createMember("scrap-dup");
        Notice notice = createNotice(member);

        scrapRepository.saveAndFlush(Scrap.builder()
                .member(member).targetType(TargetType.NOTICE).targetId(notice.getId()).build());

        assertThatThrownBy(() -> scrapRepository.saveAndFlush(Scrap.builder()
                .member(member).targetType(TargetType.NOTICE).targetId(notice.getId()).build()))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void 같은_대상에_대한_중복_신고_행은_DB가_거부한다() {
        Member reporter = createMember("report-dup");
        CommunityPost post = createPost(reporter);

        reportRepository.saveAndFlush(Report.builder()
                .reporter(reporter).targetType(Report.TargetType.POST).targetId(post.getId())
                .reason("사유").build());

        assertThatThrownBy(() -> reportRepository.saveAndFlush(Report.builder()
                .reporter(reporter).targetType(Report.TargetType.POST).targetId(post.getId())
                .reason("사유").build()))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void 동시_스크랩_요청에도_행이_둘로_늘지_않는다() throws Exception {
        Member member = createMember("scrap-race");
        Notice notice = createNotice(member);
        int callers = 8;

        List<Throwable> unexpected = runConcurrently(callers, () ->
                scrapService.toggleScrap(member.getId(), TargetType.NOTICE, notice.getId()));

        // 토글이라 마지막 상태는 0건일 수도 1건일 수도 있습니다. 막아야 하는 것은 2건 이상입니다.
        assertThat(scrapRepository.findAllByMemberIdOrderByCreatedAtDesc(member.getId()))
                .hasSizeLessThanOrEqualTo(1);
        // 중복 INSERT는 DataIntegrityViolationException으로만 떨어져야 하며(컨트롤러가 성공으로 흡수합니다),
        // 중복행이 생겼을 때 나타나는 조회 실패는 한 건도 없어야 합니다.
        assertThat(unexpected).isEmpty();

        // 중복행이 남았다면 이 조회가 IncorrectResultSizeDataAccessException으로 깨집니다.
        assertThatCode(() -> scrapRepository.findByMemberIdAndTargetTypeAndTargetId(
                member.getId(), TargetType.NOTICE, notice.getId())).doesNotThrowAnyException();
    }

    @Test
    void 동시_신고_요청에도_신고는_한_건만_적재된다() throws Exception {
        Member reporter = createMember("report-race");
        CommunityPost post = createPost(reporter);
        int callers = 8;

        List<Throwable> unexpected = runConcurrently(callers, () ->
                reportService.createReport(reporter.getId(), Report.TargetType.POST, post.getId(), "사유"));

        assertThat(reportRepository.countByTargetTypeAndTargetId(Report.TargetType.POST, post.getId()))
                .isEqualTo(1);
        assertThat(unexpected).isEmpty();
        // 신고 1건이 여러 건으로 세어지지 않으므로 자동 블라인드가 잘못 발동하지 않습니다.
        assertThat(communityPostRepository.findById(post.getId()).orElseThrow().isDeleted()).isFalse();
    }

    /**
     * 주어진 작업을 동시에 실행하고, "정상적인 경쟁 결과"가 아닌 예외만 모아 돌려줍니다.
     * 중복 INSERT가 막혀 나는 DataIntegrityViolationException과 사전 검사에서 나는
     * IllegalArgumentException("이미 신고한 대상입니다.")은 기대되는 결과입니다.
     */
    private List<Throwable> runConcurrently(int callers, Runnable task) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(callers);
        CyclicBarrier barrier = new CyclicBarrier(callers);
        List<Throwable> unexpected = new ArrayList<>();
        try {
            List<Future<?>> futures = new ArrayList<>();
            for (int i = 0; i < callers; i++) {
                futures.add(pool.submit(() -> {
                    barrier.await(5, TimeUnit.SECONDS);
                    task.run();
                    return null;
                }));
            }
            for (Future<?> future : futures) {
                try {
                    future.get(20, TimeUnit.SECONDS);
                } catch (Exception e) {
                    Throwable cause = e.getCause() == null ? e : e.getCause();
                    boolean expected = cause instanceof DataIntegrityViolationException
                            || cause instanceof IllegalArgumentException;
                    // 중복행이 남아 있을 때만 나는 예외입니다. 절대 기대 결과에 넣지 않습니다.
                    if (cause instanceof IncorrectResultSizeDataAccessException || !expected) {
                        unexpected.add(cause);
                    }
                }
            }
        } finally {
            pool.shutdownNow();
        }
        return unexpected;
    }
}
