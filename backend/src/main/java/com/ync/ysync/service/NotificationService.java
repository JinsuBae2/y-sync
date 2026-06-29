package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.Notification;
import com.ync.ysync.domain.TargetType;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final MemberRepository memberRepository;

    /**
     * 회원의 알림 내역 최신순 조회
     */
    public List<Notification> getNotifications(Long memberId) {
        return notificationRepository.findByMemberIdOrderByCreatedAtDesc(memberId);
    }

    /**
     * 회원의 모든 알림을 읽음 처리
     */
    @Transactional
    public void markAllAsRead(Long memberId) {
        notificationRepository.markAllAsReadByMemberId(memberId);
    }

    /**
     * 개별 알림 읽음 처리 (상세 페이지로 넘어갈 때 호출)
     */
    @Transactional
    public void markAsRead(Long id, Long memberId) {
        Notification notification = notificationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 알림입니다."));

        if (!notification.getMember().getId().equals(memberId)) {
            throw new IllegalArgumentException("본인의 알림만 읽을 수 있습니다.");
        }

        notification.read();
    }

    /**
     * 개별 알림 삭제
     */
    @Transactional
    public void deleteNotification(Long id, Long memberId) {
        notificationRepository.deleteByIdAndMemberId(id, memberId);
    }

    /**
     * 💡 댓글 알림 등록 (비동기 스레드에서 안전하게 호출되도록 Propagation.REQUIRES_NEW 설정 고려 또는 단순 REQUIRED)
     * 호출자가 트랜잭션이 없는 비동기 스레드이므로 REQUIRED로 시작 시 새로운 트랜잭션이 생성됩니다.
     */
    @Transactional
    public void createNotification(Long targetMemberId, String title, String body, TargetType targetType, Long targetId) {
        Member member = memberRepository.findById(targetMemberId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 회원입니다."));

        Notification notification = Notification.builder()
                .member(member)
                .title(title)
                .body(body)
                .targetType(targetType)
                .targetId(targetId)
                .build();

        notificationRepository.save(notification);
        log.info("[Notification] 인앱 알림 DB 적재 완료 - 수신 회원 ID: {}, 타입: {}, 대상 ID: {}", targetMemberId, targetType, targetId);
    }

    /**
     * 💡 공지사항 알림 일괄 등록 (Batch Save 활용)
     */
    @Transactional
    public void createNotificationsForNotice(String title, String body, Long noticeId) {
        List<Member> targetMembers = memberRepository.findAllByIsActivatedTrueAndNoticeEnabledTrue();
        if (targetMembers.isEmpty()) {
            log.info("[Notification] 공지사항 알림을 수신할 대상 회원이 없습니다.");
            return;
        }

        List<Notification> notifications = targetMembers.stream()
                .map(member -> Notification.builder()
                        .member(member)
                        .title(title)
                        .body(body)
                        .targetType(TargetType.NOTICE)
                        .targetId(noticeId)
                        .build())
                .collect(Collectors.toList());

        notificationRepository.saveAll(notifications);
        log.info("[Notification] 공지사항 알림 일괄 DB 적재 완료 - 공지 ID: {}, 대상 회원 수: {}", noticeId, notifications.size());
    }
}
