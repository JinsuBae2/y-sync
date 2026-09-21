package com.ync.ysync.service;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.Base64;

/**
 * 💡 공지 피드의 커서입니다. 마지막으로 내려준 공지의 `(createdAt, id)`를 가리킵니다.
 *
 * `createdAt`만으로는 부족합니다. UNIQUE가 아니라서 같은 시각에 두 건이 등록되면
 * 다음 페이지가 한 건을 건너뛰거나 두 번 보여줍니다. `id`를 tie-breaker로 함께 담습니다.
 *
 * 밖으로는 Base64URL 문자열로만 나갑니다. 클라이언트가 내부 구조에 기대어
 * 직접 커서를 만들기 시작하면 형식을 바꿀 수 없게 되기 때문입니다.
 */
public record NoticeCursor(LocalDateTime createdAt, Long id) {

    private static final String SEPARATOR = "|";

    public String encode() {
        String raw = createdAt + SEPARATOR + id;
        return Base64.getUrlEncoder().withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * @throws IllegalArgumentException 형식이 깨진 커서. 조용히 첫 페이지로 돌아가면 "왜 목록이
     *                                  처음으로 돌아갔는지" 알 수 없으므로 400으로 드러냅니다.
     */
    public static NoticeCursor decode(String encoded) {
        String raw;
        try {
            raw = new String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("잘못된 커서입니다.");
        }

        int separator = raw.lastIndexOf(SEPARATOR);
        if (separator < 0) {
            throw new IllegalArgumentException("잘못된 커서입니다.");
        }

        try {
            return new NoticeCursor(
                    LocalDateTime.parse(raw.substring(0, separator)),
                    Long.parseLong(raw.substring(separator + SEPARATOR.length())));
        } catch (DateTimeParseException | NumberFormatException e) {
            throw new IllegalArgumentException("잘못된 커서입니다.");
        }
    }
}
