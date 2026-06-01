package com.ync.ysync.event;

import com.ync.ysync.domain.Comment;
import com.ync.ysync.domain.Member;
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
 * 이를 통해 알림 발송 실패나 대기 시간이 메인 트랜잭션(댓글 등록)에 영향을 미치지 않도록 방어하고 중복 발송을 예방합니다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CommentEventListener {

    private final FCMService fcmService;

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleCommentCreatedEvent(CommentCreatedEvent event) {
        Comment comment = event.getComment();
        String targetType = event.getTargetType();
        Long requesterId = event.getRequesterId();

        Member author = null;
        Long targetId = null;

        // 💡 게시글의 종류에 따라 작성자 및 ID 정보 추출
        if ("NOTICE".equals(targetType) && comment.getNotice() != null) {
            author = comment.getNotice().getAuthor();
            targetId = comment.getNotice().getId();
        } else if ("COMMUNITY".equals(targetType) && comment.getCommunityPost() != null) {
            author = comment.getCommunityPost().getMember();
            targetId = comment.getCommunityPost().getId();
        }

        if (author == null || targetId == null) {
            log.warn("[FCM] 댓글 알림 발송 실패 - 대상 게시글 또는 작성자 정보를 찾을 수 없습니다.");
            return;
        }

        // 💡 발송 조건 검증: FCM 토큰 존재 여부, 본인이 작성한 댓글 제외, 댓글 알림 수신 동의 여부
        if (author.getFcmToken() != null && !author.getId().equals(requesterId) && author.isCommentEnabled()) {
            log.info("[FCM] 댓글 알림 비동기 발송 시작 - Target: {}, ID: {}, 수신자: {}", targetType, targetId, author.getName());
            
            try {
                Map<String, String> data = new HashMap<>();
                // 💡 딥링크 이동을 위해 targetType / targetId 뿐만 아니라 type / postId 필드도 함께 적재
                data.put("targetType", targetType);
                data.put("targetId", String.valueOf(targetId));
                data.put("type", targetType);
                data.put("postId", String.valueOf(targetId));

                // 💡 from y_sync 문구를 배제하고 깔끔하고 직관적인 템플릿 적용
                fcmService.sendNotificationToToken(
                        author.getFcmToken(),
                        "💬 내 글에 새로운 댓글이 달렸어요!",
                        "방금 내 작성글에 새로운 댓글이 달렸습니다.",
                        data
                );
                log.info("[FCM] 댓글 알림 비동기 발송 완료 - Target ID: {}", targetId);
            } catch (Exception e) {
                log.error("[FCM] 댓글 알림 비동기 발송 에러 - Target ID: {}", targetId, e);
            }
        } else {
            log.info("[FCM] 댓글 알림 발송 건너뜀 - 사유: fcmToken 존재여부={}, 본인댓글여부={}, 알림동의={}",
                    author.getFcmToken() != null, author.getId().equals(requesterId), author.isCommentEnabled());
        }
    }
}
