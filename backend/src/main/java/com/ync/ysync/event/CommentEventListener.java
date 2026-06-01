package com.ync.ysync.event;

import com.ync.ysync.service.FCMService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.HashMap;
import java.util.Map;

/**
 * 💡 댓글 알림 발송을 트랜잭션 종료 후에 비동기로 수행하는 이벤트 리스너 클래스입니다.
 * 전달받은 이벤트의 수신자 정보를 직접 사용하여 지연 로딩 예외(LazyInitializationException)를 방지하고
 * 정확한 타겟팅으로 알림을 단 1회 안전하게 발송합니다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CommentEventListener {

    private final FCMService fcmService;

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleCommentCreatedEvent(CommentCreatedEvent event) {
        Long targetMemberId = event.getTargetMemberId();
        String targetFcmToken = event.getTargetFcmToken();
        boolean targetCommentEnabled = event.isTargetCommentEnabled();
        Long requesterId = event.getRequesterId();
        String targetType = event.getTargetType();
        Long targetId = event.getTargetId();

        // 💡 [버그 픽스 2] 본인 글에 본인이 댓글을 작성하는 경우 알림 발송을 원천 차단 (스킵)
        if (targetMemberId != null && targetMemberId.equals(requesterId)) {
            log.info("[FCM] 댓글 알림 스킵 - 본인 글에 본인이 남긴 댓글. Target Member ID: {}, Requester ID: {}", targetMemberId, requesterId);
            return;
        }

        // 💡 발송 대상 검증: FCM 토큰 유무, 알림 허용 여부
        if (targetFcmToken != null && !targetFcmToken.isEmpty() && targetCommentEnabled) {
            log.info("[FCM] 댓글 알림 비동기 발송 시작 - Target Type: {}, ID: {}, Token: {}...", 
                    targetType, targetId, targetFcmToken.substring(0, Math.min(targetFcmToken.length(), 20)));
            
            try {
                Map<String, String> data = new HashMap<>();
                // 💡 딥링크 이동을 위해 targetType / targetId 뿐만 아니라 type / postId 필드도 함께 적재
                data.put("targetType", targetType);
                data.put("targetId", String.valueOf(targetId));
                data.put("type", targetType);
                data.put("postId", String.valueOf(targetId));

                // 💡 from y_sync 문구를 배제하고 깔끔하고 직관적인 템플릿 적용
                fcmService.sendNotificationToToken(
                        targetFcmToken,
                        "💬 내 글에 새로운 댓글이 달렸어요!",
                        "방금 내 작성글에 새로운 댓글이 달렸습니다.",
                        data
                );
                log.info("[FCM] 댓글 알림 비동기 발송 성공 - Target ID: {}", targetId);
            } catch (Exception e) {
                log.error("[FCM] 댓글 알림 비동기 발송 실패 - Target ID: {}", targetId, e);
            }
        } else {
            log.info("[FCM] 댓글 알림 발송 건너뜀 - 사유: fcmToken 존재여부={}, 알림동의={}", 
                    targetFcmToken != null, targetCommentEnabled);
        }
    }
}
