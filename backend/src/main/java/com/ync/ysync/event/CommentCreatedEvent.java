package com.ync.ysync.event;

import com.ync.ysync.domain.Comment;
import lombok.Getter;
import org.springframework.context.ApplicationEvent;

/**
 * 💡 댓글 작성 완료 시 발행되는 스프링 이벤트 클래스입니다.
 * 비동기 알림 전송 처리를 위해 작성자 ID, 댓글 도메인 객체를 포함합니다.
 */
@Getter
public class CommentCreatedEvent extends ApplicationEvent {

    private final Comment comment;
    private final String targetType; // "NOTICE" 또는 "COMMUNITY"
    private final Long requesterId;   // 댓글을 작성한 사람의 ID (본인 알림 제외용)

    public CommentCreatedEvent(Object source, Comment comment, String targetType, Long requesterId) {
        super(source);
        this.comment = comment;
        this.targetType = targetType;
        this.requesterId = requesterId;
    }
}
