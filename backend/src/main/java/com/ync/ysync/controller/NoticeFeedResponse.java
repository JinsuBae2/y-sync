package com.ync.ysync.controller;

import com.ync.ysync.service.NoticeService;

import java.util.List;

/**
 * 💡 공지 피드 한 페이지 응답입니다.
 *
 * @param pinned     고정 공지. 첫 페이지에서만 채워집니다. 이후 페이지에서는 빈 배열입니다.
 * @param items      일반 공지, 최신순
 * @param nextCursor 다음 요청에 그대로 넘길 값. null이면 마지막 페이지입니다.
 *                   내용은 불투명 문자열이니 클라이언트가 해석하지 않습니다.
 * @param hasNext    `nextCursor != null`과 같지만, 클라이언트 조건문이 읽기 쉬우라고 함께 줍니다.
 * @param latestId   같은 필터에서 가장 최근 공지의 id. 새 공지 감지(`/feed-updates`) 기준값입니다.
 */
public record NoticeFeedResponse(List<NoticeResponse> pinned,
                                 List<NoticeResponse> items,
                                 String nextCursor,
                                 boolean hasNext,
                                 Long latestId) {

    public static NoticeFeedResponse from(NoticeService.NoticeFeed feed) {
        return new NoticeFeedResponse(
                feed.pinned().stream().map(NoticeResponse::from).toList(),
                feed.items().stream().map(NoticeResponse::from).toList(),
                feed.nextCursor(),
                feed.hasNext(),
                feed.latestId());
    }
}
