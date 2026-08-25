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
