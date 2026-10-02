package com.ync.ysync.service;

import com.ync.ysync.domain.Report;
import com.ync.ysync.domain.TargetType;
import com.ync.ysync.repository.CommentRepository;
import com.ync.ysync.repository.ReportRepository;
import com.ync.ysync.repository.ScrapRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 💡 글을 하드 삭제하기 전에 그 글에 매달린 데이터를 정리합니다.
 *
 * 정리 대상은 두 갈래입니다.
 *
 * 1. FK가 걸린 것 — `comment.community_post_id`, `comment.notice_id`. 운영 DB에 실제로 FK 제약이
 *    존재하는 것을 확인했습니다. 남겨 두면 글 삭제 자체가 제약 위반으로 실패합니다.
 *    즉 **댓글이 하나라도 달린 글은 삭제할 수 없었습니다.**
 *    이미지는 `CommunityPost.images`·`Notice.images`의 cascade가 처리하므로 여기서 다루지 않습니다.
 * 2. FK가 없는 것 — `scrap.target_id`, `report.target_id`. 타입과 ID로만 가리키는 구조라
 *    DB가 막아 주지 않습니다. 삭제를 막지는 않지만, 남으면 관리자 신고함에 열 수 없는 항목이
 *    쌓이고 스크랩 목록에 빈 자리가 생깁니다.
 *
 * 알림(`notification`)은 정리하지 않습니다. 이미 발송된 내역이라 지우면 사용자의 수신 기록이
 * 사라지고, 대상이 없는 알림은 프론트에서 이동 실패로 처리하면 되는 범위입니다.
 *
 * 모든 메서드는 호출한 삭제 트랜잭션 안에서 실행돼야 합니다(`MANDATORY`).
 * 정리만 커밋되고 글 삭제가 실패하면 댓글만 사라진 글이 남기 때문입니다.
 */
@Component
@RequiredArgsConstructor
public class PostDeletionCleaner {

    private final CommentRepository commentRepository;
    private final ScrapRepository scrapRepository;
    private final ReportRepository reportRepository;

    @Transactional(propagation = Propagation.MANDATORY)
    public void cleanUpCommunityPost(Long postId) {
        deleteCommentReports(commentRepository.findIdsByCommunityPostId(postId));

        // 대댓글 → 원 댓글 순서입니다. comment.parent_id 가 comment 자기 자신을 참조합니다.
        commentRepository.deleteRepliesByCommunityPostId(postId);
        commentRepository.deleteAllByCommunityPostId(postId);

        reportRepository.deleteByTargetTypeAndTargetId(Report.TargetType.POST, postId);
        scrapRepository.deleteAllByTargetTypeAndTargetId(TargetType.COMMUNITY, postId);
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void cleanUpNotice(Long noticeId) {
        deleteCommentReports(commentRepository.findIdsByNoticeId(noticeId));

        commentRepository.deleteRepliesByNoticeId(noticeId);
        commentRepository.deleteAllByNoticeId(noticeId);

        // 공지 자체는 신고 대상이 아니므로(Report.TargetType은 POST·COMMENT) 댓글 신고만 정리하면 됩니다.
        scrapRepository.deleteAllByTargetTypeAndTargetId(TargetType.NOTICE, noticeId);
    }

    private void deleteCommentReports(List<Long> commentIds) {
        if (commentIds.isEmpty()) {
            return; // IN () 은 유효한 SQL이 아닙니다.
        }
        reportRepository.deleteAllByTargetTypeAndTargetIdIn(Report.TargetType.COMMENT, commentIds);
    }
}
