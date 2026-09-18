package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeGradePreference;
import com.ync.ysync.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 💡 공지 알림 수신자를 한 번만 선정합니다.
 *
 * 앱 알림함 저장과 푸시 발송이 같은 목록을 사용해야 두 경로의 학년 판정이 어긋나지 않습니다.
 *
 * 대상 조건은 다음 세 가지입니다.
 * <ol>
 *   <li>활성 회원</li>
 *   <li>공지 알림 수신 동의</li>
 *   <li>전체 공지이거나, 회원의 선택 학년과 공지 대상 학년이 일치</li>
 * </ol>
 *
 * 세 번째 조건은 {@code ysync.notification.grade-filter.enabled}로 켭니다. 도입 1단계에서는 꺼 두어
 * 기존 발송 범위를 유지하고, 학생들이 학년을 선택한 뒤 운영자가 전환 시점을 정해 켭니다.
 * 문제가 생기면 이 설정만 되돌리면 기존 발송 방식으로 복구되며, 저장된 회원 학년 데이터는 보존됩니다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NoticeRecipientSelector {

    private final MemberRepository memberRepository;

    @Value("${ysync.notification.grade-filter.enabled:false}")
    private boolean gradeFilterEnabled;

    public List<Member> selectRecipients(Notice notice) {
        List<Member> candidates = memberRepository.findAllByIsActivatedTrueAndNoticeEnabledTrue();

        if (!gradeFilterEnabled) {
            return candidates;
        }

        // 💡 올해 학년을 확인하지 않았다는 이유로 기존 학년 알림을 끊지는 않습니다.
        //    확인 학년도는 안내 시점을 정하는 값이며 수신 대상 판정에는 쓰지 않습니다.
        List<Member> recipients = candidates.stream()
                .filter(member -> NoticeGradePreference.receives(
                        member.getNoticeGradePreference(), notice.getTargetGrade()))
                .toList();

        log.info("[Notification] 공지 수신자 선정 - 공지 ID: {}, 대상 학년: {}, 후보: {}명, 수신: {}명",
                notice.getId(), notice.getTargetGrade(), candidates.size(), recipients.size());
        return recipients;
    }

    public boolean isGradeFilterEnabled() {
        return gradeFilterEnabled;
    }
}
