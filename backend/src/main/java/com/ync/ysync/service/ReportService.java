package com.ync.ysync.service;

import com.ync.ysync.domain.*;
import com.ync.ysync.repository.CommentRepository;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.ReportRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReportService {

    private final ReportRepository reportRepository;
    private final MemberRepository memberRepository;
    private final CommunityPostRepository communityPostRepository;
    private final CommentRepository commentRepository;
    private final CommentService commentService;

    @Transactional
    public void createReport(Long reporterId, Report.TargetType targetType, Long targetId, String reason) {
        // 1. 중복 신고 방지
        if (reportRepository.existsByReporterIdAndTargetTypeAndTargetId(reporterId, targetType, targetId)) {
            throw new IllegalArgumentException("이미 신고한 대상입니다.");
        }

        Member reporter = memberRepository.findById(reporterId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 회원입니다."));

        // 2. 타겟 존재 여부 검증
        if (targetType == Report.TargetType.POST) {
            CommunityPost post = communityPostRepository.findById(targetId)
                    .orElseThrow(() -> new IllegalArgumentException("신고 대상 게시글이 존재하지 않습니다."));
            if (post.isDeleted()) {
                throw new IllegalArgumentException("이미 삭제되거나 블라인드 처리된 게시글입니다.");
            }
        } else if (targetType == Report.TargetType.COMMENT) {
            Comment comment = commentRepository.findById(targetId)
                    .orElseThrow(() -> new IllegalArgumentException("신고 대상 댓글이 존재하지 않습니다."));
            if (comment.isDeleted()) {
                throw new IllegalArgumentException("이미 삭제되거나 블라인드 처리된 댓글입니다.");
            }
        }

        // 3. 신고 저장
        Report report = Report.builder()
                .reporter(reporter)
                .targetType(targetType)
                .targetId(targetId)
                .reason(reason)
                .build();

        reportRepository.save(report);

        // 4. 누적 신고 수 조회 및 자동 블라인드 처리 (5회 이상)
        long count = reportRepository.countByTargetTypeAndTargetId(targetType, targetId);
        if (count >= 5) {
            String blindReason = "신고 누적으로 인한 자동 숨김 처리";
            if (targetType == Report.TargetType.POST) {
                CommunityPost post = communityPostRepository.findById(targetId).orElseThrow();
                post.deleteByAdmin(blindReason);
                communityPostRepository.save(post);
                log.info("게시글 {}번이 신고 5회 누적으로 자동 블라인드 처리되었습니다.", targetId);
            } else if (targetType == Report.TargetType.COMMENT) {
                Comment comment = commentRepository.findById(targetId).orElseThrow();
                if (comment.isDeleted()) {
                    return;
                }
                commentService.deleteCommentByAdmin(comment.getId(), blindReason);

                log.info("댓글 {}번이 신고 5회 누적으로 자동 블라인드 처리되었습니다.", targetId);
            }
        }

    }
}
