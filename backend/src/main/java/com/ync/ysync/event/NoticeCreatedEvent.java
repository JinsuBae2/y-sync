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

    public NoticeCreatedEvent(Object source, Notice notice) {
        super(source);
        this.notice = notice;
    }
}
