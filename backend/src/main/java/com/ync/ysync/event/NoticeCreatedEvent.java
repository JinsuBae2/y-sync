package com.ync.ysync.event;

import com.ync.ysync.domain.Notice;
import lombok.Getter;
import org.springframework.context.ApplicationEvent;

/**
 * 💡 공지사항이 새로 생성되었을 때 발행되는 스프링 이벤트 클래스입니다.
 */
@Getter
public class NoticeCreatedEvent extends ApplicationEvent {
    
    private final Notice notice;

    /**
     * 💡 작성자 id를 엔티티에서 꺼내지 않고 이벤트에 실어 보냅니다.
     *
     * 이 이벤트는 `@Async` + `AFTER_COMMIT`에서 처리되므로 그 시점의 {@code notice}는 준영속입니다.
     * `notice.getAuthor().getId()`는 지연 로딩 프록시에서도 식별자만 꺼내므로 지금은 동작하지만,
     * 나중에 누가 `getName()` 같은 걸 덧붙이면 조용히 깨집니다. 트랜잭션 안에서 확정해 넘깁니다.
     * `CommentCreatedEvent`가 이미 같은 방식을 씁니다.
     */
    private final Long authorId;

    public NoticeCreatedEvent(Object source, Notice notice, Long authorId) {
        super(source);
        this.notice = notice;
        this.authorId = authorId;
    }
}
