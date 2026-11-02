package com.ync.ysync.service;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Base64;

public record NotificationCursor(LocalDateTime createdAt, long id) {
    public String encode() {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(
                (createdAt + "|" + id).getBytes(StandardCharsets.UTF_8));
    }

    public static NotificationCursor decode(String encoded) {
        try {
            String[] parts = new String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8).split("\\|", -1);
            if (parts.length != 2) throw new IllegalArgumentException();
            long id = Long.parseLong(parts[1]);
            if (id <= 0) throw new IllegalArgumentException();
            return new NotificationCursor(LocalDateTime.parse(parts[0]), id);
        } catch (RuntimeException e) {
            throw new IllegalArgumentException("잘못된 커서입니다.");
        }
    }
}
