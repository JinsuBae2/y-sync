package com.ync.ysync.event;

import com.ync.ysync.domain.Notice;
import com.ync.ysync.service.FCMService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.event.TransactionPhase;

import java.util.HashMap;
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

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleNoticeCreatedEvent(NoticeCreatedEvent event) {
        Notice notice = event.getNotice();
        log.info("[FCM] 공지사항 알림 발송 시작 - Notice ID: {}, Title: '{}', Thread: {}", 
                notice.getId(), notice.getTitle(), Thread.currentThread().getName());

        try {
            Map<String, String> data = new HashMap<>();
            data.put("targetType", "NOTICE");
            data.put("targetId", String.valueOf(notice.getId()));

            fcmService.sendNotificationToTopic(
                    "all", 
                    "[새 공지사항] " + notice.getTitle(), 
                    "새로운 공지사항이 등록되었습니다.", 
                    data
            );
            log.info("[FCM] 공지사항 알림 발송 성공 - Notice ID: {}", notice.getId());
        } catch (Exception e) {
            log.error("[FCM] 공지사항 알림 발송 실패 - Notice ID: {}", notice.getId(), e);
        }
    }
}
