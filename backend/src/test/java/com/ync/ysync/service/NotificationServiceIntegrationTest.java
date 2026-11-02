package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notification;
import com.ync.ysync.domain.TargetType;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NotificationRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@Transactional
class NotificationServiceIntegrationTest {

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private MemberRepository memberRepository;

    @MockitoBean
    private JavaMailSender mailSender;

    @Test
    void marksOnlyTheMembersUnreadNotificationsAsRead() {
        Member targetMember = saveMember("notification-target");
        Member otherMember = saveMember("notification-other");

        notificationRepository.saveAllAndFlush(List.of(
                notification(targetMember, 1L),
                notification(targetMember, 2L),
                notification(otherMember, 3L)
        ));

        int updatedCount = notificationService.markAllAsRead(targetMember.getId());

        assertEquals(2, updatedCount);
        assertTrue(notificationService.getNotifications(targetMember.getId())
                .stream()
                .allMatch(Notification::isRead));
        assertFalse(notificationService.getNotifications(otherMember.getId()).getFirst().isRead());
    }

    @Autowired jakarta.persistence.EntityManager entityManager;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;

    @Test
    void pagesEqualTimestampsWithoutDuplicatesAndScopesUnreadCountToMember() {
        Member target = saveMember("feed-target");
        Member other = saveMember("feed-other");
        java.util.ArrayList<Long> expected = new java.util.ArrayList<>();
        for (long i = 0; i < 25; i++) {
            Notification n = notificationRepository.saveAndFlush(notification(target, i));
            jdbc.update("update notification set created_at = ? where id = ?",
                    java.time.LocalDateTime.of(2026, 11, 2, 9, 0), n.getId());
            expected.add(n.getId());
        }
        notificationRepository.saveAndFlush(notification(other, 50L));
        entityManager.clear();
        var first = notificationService.getFeed(target.getId(), null, 20);
        assertEquals(20, first.items().size());
        assertEquals(25, first.unreadCount());
        var next = notificationService.getFeed(target.getId(), first.nextCursor(), 20);
        var actual = new java.util.ArrayList<Long>();
        first.items().forEach(n -> actual.add(n.getId()));
        next.items().forEach(n -> actual.add(n.getId()));
        assertEquals(expected.reversed(), actual);
        assertFalse(next.hasNext());
        notificationService.markAsRead(first.items().getFirst().getId(), target.getId());
        assertEquals(24, notificationService.getFeed(target.getId(), null, 20).unreadCount());
        notificationService.markAllAsRead(target.getId());
        assertEquals(0, notificationService.getFeed(target.getId(), null, 20).unreadCount());
        assertEquals(1, notificationService.getFeed(other.getId(), null, 20).unreadCount());
    }

    @Test
    void insertAndCursorDeletionDoNotShiftNextPage() {
        Member target = saveMember("feed-insert");
        Notification oldest = notificationRepository.saveAndFlush(notification(target, 1L));
        Notification middle = notificationRepository.saveAndFlush(notification(target, 2L));
        notificationRepository.saveAndFlush(notification(target, 3L));
        var first = notificationService.getFeed(target.getId(), null, 2);
        notificationRepository.saveAndFlush(notification(target, 4L));
        notificationService.deleteNotification(middle.getId(), target.getId());
        var next = notificationService.getFeed(target.getId(), first.nextCursor(), 2);
        assertEquals(List.of(oldest.getId()), next.items().stream().map(Notification::getId).toList());
    }

    @Test
    void rejectsInvalidCursorAndPageSize() {
        Member target = saveMember("feed-invalid");
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
                () -> notificationService.getFeed(target.getId(), "bad", 20));
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
                () -> notificationService.getFeed(target.getId(), null, 0));
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
                () -> notificationService.getFeed(target.getId(), null, 51));
    }

    private Member saveMember(String loginId) {
        Member member = Member.builder()
                .loginId(loginId)
                .password("encoded-password")
                .name(loginId)
                .role(MemberRole.USER)
                .isActivated(true)
                .build();
        return memberRepository.save(member);
    }

    private Notification notification(Member member, Long targetId) {
        return Notification.builder()
                .member(member)
                .title("새 공지")
                .body("공지 내용")
                .targetType(TargetType.NOTICE)
                .targetId(targetId)
                .build();
    }
}
