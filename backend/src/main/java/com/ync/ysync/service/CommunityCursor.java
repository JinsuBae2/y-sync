package com.ync.ysync.service;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Base64;

public record CommunityCursor(boolean pinned, LocalDateTime createdAt, long id) {
    public String encode() {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(
                ((pinned ? "1" : "0") + "|" + createdAt + "|" + id).getBytes(StandardCharsets.UTF_8));
    }

    public static CommunityCursor decode(String encoded) {
        try {
            String[] parts = new String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8).split("\\|", -1);
            if (parts.length != 3 || !(parts[0].equals("0") || parts[0].equals("1"))) throw new IllegalArgumentException();
            long id = Long.parseLong(parts[2]);
            if (id <= 0) throw new IllegalArgumentException();
            return new CommunityCursor(parts[0].equals("1"), LocalDateTime.parse(parts[1]), id);
        } catch (RuntimeException e) {
            throw new IllegalArgumentException("잘못된 커서입니다.");
        }
    }
}
