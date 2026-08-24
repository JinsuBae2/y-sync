package com.ync.ysync.controller;

import com.ync.ysync.config.AuthUtil;
import com.ync.ysync.domain.Notification;
import com.ync.ysync.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;
    private final AuthUtil authUtil;

    /**
     * 💡 회원이 수신한 알림 내역 최신순 조회
     */
    @GetMapping
    public ResponseEntity<?> getNotifications() {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");
        }

        List<Notification> notifications = notificationService.getNotifications(memberId);
        List<NotificationResponse> responses = notifications.stream()
                .map(NotificationResponse::from)
                .collect(Collectors.toList());

        return ResponseEntity.ok(responses);
    }

    /**
     * 💡 회원의 모든 알림을 전체 읽음 처리
     */
    @PutMapping("/read")
    public ResponseEntity<?> markAllAsRead() {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");
        }

        notificationService.markAllAsRead(memberId);
        log.info("[Notification API] 회원 ID {}의 전체 알림 읽음 처리 완료", memberId);
        return ResponseEntity.ok("전체 읽음 처리 완료");
    }

    /**
     * 💡 개별 알림 읽음 처리 (특정 알림 클릭/탭 시 호출)
     */
    @PutMapping("/{id}/read")
    public ResponseEntity<?> markAsRead(@PathVariable Long id) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");
        }

        try {
            notificationService.markAsRead(id, memberId);
            log.info("[Notification API] 알림 ID {}, 회원 ID {} 개별 읽음 처리 완료", id, memberId);
            return ResponseEntity.ok("개별 읽음 처리 완료");
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    /**
     * 💡 개별 알림 삭제
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteNotification(@PathVariable Long id) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");
        }

        notificationService.deleteNotification(id, memberId);
        log.info("[Notification API] 알림 ID {}, 회원 ID {} 개별 삭제 완료", id, memberId);
        return ResponseEntity.ok("알림 삭제 완료");
    }
}
