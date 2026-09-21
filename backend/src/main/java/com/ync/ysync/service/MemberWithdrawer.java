package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.repository.AdminRequestRepository;
import com.ync.ysync.repository.NotificationRepository;
import com.ync.ysync.repository.PersonalTimetableEntryRepository;
import com.ync.ysync.repository.ScrapRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 💡 회원을 삭제하는 대신 계정을 익명화합니다.
 *
 * 운영 DB에서 `member`를 참조하는 외래키가 8개(admin_request, comment, community_post, notice,
 * notification, personal_timetable_entry, report, scrap)인 것을 확인했습니다. 회원 행을 그대로
 * 지우면 글이나 댓글을 쓴 적 있는 회원은 제약 위반으로 삭제 자체가 실패하고, 억지로 딸린 데이터까지
 * 지우면 **그 사람의 글에 달린 다른 학생의 댓글까지 함께 사라집니다.**
 *
 * 그래서 행은 남기고 개인을 특정할 수 있는 값만 지웁니다.
 *
 * - 계정에서 지우는 것: 학번, 이메일, 이름, 소셜 ID, FCM 토큰, 알림 설정, 권한
 * - 함께 지우는 것: 본인만 보는 데이터 — 수신 알림, 스크랩, 개인 시간표, 권한 신청 이력
 * - 남기는 것: 글과 댓글. 작성자 이름은 "탈퇴한 학생"으로 보입니다. 신고 이력도 남습니다.
 *   신고자 식별 정보가 이미 지워졌고, 지우면 누적 신고 수가 줄어 처리 중인 건의 판단이 바뀝니다.
 *
 * 정리와 익명화가 한 트랜잭션 안에서 함께 커밋돼야 하므로 `MANDATORY`입니다.
 */
@Component
@RequiredArgsConstructor
public class MemberWithdrawer {

    private final NotificationRepository notificationRepository;
    private final ScrapRepository scrapRepository;
    private final PersonalTimetableEntryRepository personalTimetableEntryRepository;
    private final AdminRequestRepository adminRequestRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional(propagation = Propagation.MANDATORY)
    public void withdraw(Member member) {
        Long memberId = member.getId();

        notificationRepository.deleteAllByMemberId(memberId);
        scrapRepository.deleteAllByMemberId(memberId);
        personalTimetableEntryRepository.deleteAllByMemberId(memberId);
        adminRequestRepository.deleteAllByRequesterId(memberId);

        // loginId는 NOT NULL·UNIQUE라 비울 수 없습니다. 학번과 겹치지 않는 값으로 바꿉니다.
        // 학번이 풀리므로 같은 학생을 다시 사전 등록할 수 있습니다.
        member.withdraw(
                "withdrawn-" + memberId,
                passwordEncoder.encode(UUID.randomUUID().toString()),
                LocalDateTime.now());
    }
}
