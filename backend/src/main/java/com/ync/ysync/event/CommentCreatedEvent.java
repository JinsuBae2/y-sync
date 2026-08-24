package com.ync.ysync.event;

import lombok.Getter;
import org.springframework.context.ApplicationEvent;

/**
 * 💡 댓글 작성 완료 시 발행되는 스프링 이벤트 클래스입니다.
 * 비동기 스레드에서의 JPA 지연 로딩 예외(LazyInitializationException)를 원천 차단하기 위해,
 * 트랜잭션이 활성화된 상태에서 FCM 발송에 필요한 수신자 정보를 모두 담아 전달합니다.
 */
@Getter
public class CommentCreatedEvent extends ApplicationEvent {

    private final Long targetMemberId;      // 💡 알림을 수신할 원문 작성자 ID
    private final String targetFcmToken;    // 💡 수신자 FCM 토큰
    private final boolean targetCommentEnabled; // 💡 수신자의 댓글 알림 동의 여부
    private final Long requesterId;         // 💡 댓글을 작성한 사람의 ID (본인 알림 제외용)
    private final String targetType;        // 💡 "NOTICE" 또는 "COMMUNITY"
    private final Long targetId;            // 💡 원문 게시글 ID
    private final String commentContent;    // 💡 댓글 내용

    public CommentCreatedEvent(Object source, Long targetMemberId, String targetFcmToken,
                               boolean targetCommentEnabled, Long requesterId, 
                               String targetType, Long targetId, String commentContent) {
        super(source);
        this.targetMemberId = targetMemberId;
        this.targetFcmToken = targetFcmToken;
        this.targetCommentEnabled = targetCommentEnabled;
        this.requesterId = requesterId;
        this.targetType = targetType;
        this.targetId = targetId;
        this.commentContent = commentContent;
    }
}
