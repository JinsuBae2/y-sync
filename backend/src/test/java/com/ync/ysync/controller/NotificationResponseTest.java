package com.ync.ysync.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ync.ysync.domain.TargetType;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class NotificationResponseTest {

    private final ObjectMapper objectMapper = new ObjectMapper().findAndRegisterModules();

    @Test
    void serializesReadStateAsIsRead() throws Exception {
        NotificationResponse response = new NotificationResponse(
                1L,
                "새 공지",
                "공지 내용",
                TargetType.NOTICE,
                10L,
                true,
                LocalDateTime.of(2026, 8, 25, 12, 0)
        );

        JsonNode json = objectMapper.valueToTree(response);

        assertTrue(json.get("isRead").booleanValue());
        assertFalse(json.has("read"));
    }
}
