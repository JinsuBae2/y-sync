package com.ync.ysync.event;

import com.ync.ysync.domain.Notice;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.service.FCMService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.event.TransactionPhase;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 💡 공지사항 생성 이벤트를 비동기로 처리하는 이벤트 리스너입니다.
 * 트랜잭션 커밋 이후(AFTER_COMMIT)에 실행되어 데이터 정합성을 보장합니다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NoticeEventListener {

    private final FCMService fcmService;
    private final MemberRepository memberRepository;

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleNoticeCreatedEvent(NoticeCreatedEvent event) {
        Notice notice = event.getNotice();
        log.info("[FCM] 공지사항 알림 발송 시작 - Notice ID: {}, Title: '{}', Thread: {}", 
                notice.getId(), notice.getTitle(), Thread.currentThread().getName());

        try {
            // 💡 [웹앱 알림 제약 해결] 전체 활성 회원의 FCM 토큰 조회
            List<String> fcmTokens = memberRepository.findAllFcmTokensOfActivatedMembers();
            
            if (fcmTokens.isEmpty()) {
                log.info("[FCM] 알림을 수신할 활성화된 회원이 없습니다. 발송을 스킵합니다. Notice ID: {}", notice.getId());
                return;
            }

            Map<String, String> data = new HashMap<>();
            data.put("targetType", "NOTICE");
            data.put("targetId", String.valueOf(notice.getId()));

            // 💡 멀티캐스트 방식으로 발송 (FCMService 내에서 500개 단위 분할 전송)
            fcmService.sendNotificationToTokens(
                    fcmTokens,
                    "[새 공지사항] " + notice.getTitle(), 
                    "새로운 공지사항이 등록되었습니다.", 
                    data
            );
            log.info("[FCM] 공지사항 알림 발송 성공 - Notice ID: {}, 발송 기기 수: {}", notice.getId(), fcmTokens.size());
        } catch (Exception e) {
            log.error("[FCM] 공지사항 알림 발송 실패 - Notice ID: {}", notice.getId(), e);
        }
    }
}
