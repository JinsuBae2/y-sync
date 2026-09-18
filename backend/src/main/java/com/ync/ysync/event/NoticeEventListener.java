package com.ync.ysync.event;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.service.FCMService;
import com.ync.ysync.service.NoticeRecipientSelector;
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
    private final NoticeRecipientSelector noticeRecipientSelector;
    private final com.ync.ysync.service.NotificationService notificationService;

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleNoticeCreatedEvent(NoticeCreatedEvent event) {
        Notice notice = event.getNotice();
        log.info("[FCM] 공지사항 알림 발송 시작 - Notice ID: {}, Title: '{}', Thread: {}", 
                notice.getId(), notice.getTitle(), Thread.currentThread().getName());

        // 💡 0. 수신자를 한 번만 선정합니다. 앱 알림함과 푸시가 같은 목록을 사용해야 학년 판정이 어긋나지 않습니다.
        List<Member> recipients;
        try {
            recipients = noticeRecipientSelector.selectRecipients(notice);
        } catch (Exception e) {
            log.error("[Notification] 공지 수신자 선정 실패 - Notice ID: {}, 사유: {}", notice.getId(), e.getMessage(), e);
            return;
        }

        // 💡 1. 인앱 알림 DB 적재 (선정된 수신자 대상, 푸시 토큰이 없어도 저장)
        try {
            notificationService.createNotificationsForNotice(
                    recipients,
                    "[새 공지사항] " + notice.getTitle(),
                    "새로운 공지사항이 등록되었습니다.",
                    notice.getId()
            );
        } catch (Exception e) {
            log.error("[Notification] 공지사항 인앱 알림 일괄 DB 적재 실패 - Notice ID: {}, 사유: {}", notice.getId(), e.getMessage(), e);
        }

        // 💡 2. 푸시 발송. 실패해도 위의 앱 알림함 저장을 되돌리지 않도록 독립적으로 처리합니다.
        try {
            List<String> fcmTokens = recipients.stream()
                    .map(Member::getFcmToken)
                    .filter(token -> token != null && !token.isBlank())
                    .distinct()
                    .toList();
            
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
