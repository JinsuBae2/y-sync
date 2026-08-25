package com.ync.ysync.controller;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.ync.ysync.domain.Notification;
import com.ync.ysync.domain.TargetType;
import lombok.AllArgsConstructor;
import lombok.AccessLevel;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@AllArgsConstructor
public class NotificationResponse {
    private Long id;
    private String title;
    private String body;
    private TargetType targetType;
    private Long targetId;
    @Getter(AccessLevel.NONE)
    private boolean isRead;
    private LocalDateTime createdAt;

    @JsonProperty("isRead")
    public boolean isRead() {
        return isRead;
    }

    public static NotificationResponse from(Notification notification) {
        return new NotificationResponse(
                notification.getId(),
                notification.getTitle(),
                notification.getBody(),
                notification.getTargetType(),
                notification.getTargetId(),
                notification.isRead(),
                notification.getCreatedAt()
        );
    }
}
