package com.ync.ysync.event;

import com.ync.ysync.domain.Notice;
import com.ync.ysync.service.FCMService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;

/**
 * 💡 공지사항 생성 이벤트를 비동기로 처리하는 이벤트 리스너입니다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NoticeEventListener {

    private final FCMService fcmService;

    @Async
    @EventListener
    public void handleNoticeCreatedEvent(NoticeCreatedEvent event) {
        Notice notice = event.getNotice();
        log.info("Starting asynchronous FCM notification send for Notice ID: {} on thread: {}", 
                notice.getId(), Thread.currentThread().getName());

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
            log.info("Asynchronous FCM notification sent successfully for Notice ID: {}", notice.getId());
        } catch (Exception e) {
            log.error("Failed to send FCM notification asynchronously for Notice ID: {}", notice.getId(), e);
        }
    }
}
