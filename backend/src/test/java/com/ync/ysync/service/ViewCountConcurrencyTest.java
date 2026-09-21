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
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
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
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 💡 조회수가 동시 조회에서 유실되지 않는지 고정하는 테스트입니다.
 *
 * 이전 구현은 엔티티 필드를 읽어 +1 하고 저장하는 방식이라, 두 사람이 거의 동시에 글을 열면
 * 둘 다 같은 값을 읽어 조회수가 1만 올라갔습니다(lost update).
 *
 * 트랜잭션을 실제로 커밋해 경쟁 상황을 재현해야 하므로 클래스에 @Transactional을 걸지 않습니다.
 */
@SpringBootTest
class ViewCountConcurrencyTest {

    @Autowired private NoticeService noticeService;
    @Autowired private NoticeRepository noticeRepository;
    @Autowired private MemberRepository memberRepository;

    @MockitoBean private JavaMailSender javaMailSender;

    private Notice createNotice() {
        Member author = memberRepository.save(Member.builder()
                .loginId("view-" + System.nanoTime()).password("encoded").name("작성자")
                .role(MemberRole.ADMIN).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(true).isSuspended(false)
                .build());
        return noticeRepository.save(new Notice(
                "조회수 테스트", "내용", author, NoticeType.NOTICE, null, Grade.ALL, false, null, null));
    }

    @Test
    void 동시에_열어도_조회수가_유실되지_않는다() throws Exception {
        Notice notice = createNotice();
        int readers = 16;

        ExecutorService pool = Executors.newFixedThreadPool(readers);
        CyclicBarrier barrier = new CyclicBarrier(readers);
        try {
            List<Future<?>> futures = new ArrayList<>();
            for (int i = 0; i < readers; i++) {
                futures.add(pool.submit(() -> {
                    try {
                        barrier.await(5, TimeUnit.SECONDS);
                        noticeService.getNotice(notice.getId());
                    } catch (Exception e) {
                        throw new IllegalStateException(e);
                    }
                }));
            }
            for (Future<?> future : futures) {
                future.get(20, TimeUnit.SECONDS);
            }
        } finally {
            pool.shutdownNow();
        }

        // 이전 구현에서는 이 값이 16보다 작아졌습니다.
        assertThat(noticeRepository.findById(notice.getId()).orElseThrow().getViewCount())
                .isEqualTo(readers);
    }

    @Test
    void 조회_응답은_증가된_조회수를_담는다() {
        Notice notice = createNotice();

        assertThat(noticeService.getNotice(notice.getId()).getViewCount()).isEqualTo(1);
        assertThat(noticeService.getNotice(notice.getId()).getViewCount()).isEqualTo(2);
    }

    @Test
    void 없는_글은_조회수를_올리지_않고_예외를_던진다() {
        assertThatThrownBy(() -> noticeService.getNotice(999_999_999L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("존재하지 않습니다");
    }
}
