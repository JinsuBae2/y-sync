package com.ync.ysync.controller;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.ync.ysync.domain.AdminRequest;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Report;
import com.ync.ysync.repository.AdminRequestRepository;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.CommentRepository;
import com.ync.ysync.repository.ReportRepository;
import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.Comment;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.repository.NoticeRepository;
import com.ync.ysync.config.AuthUtil;
import lombok.AllArgsConstructor;
import lombok.AccessLevel;
import lombok.Builder; // 💡 추가
import lombok.Data;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminRequestRepository adminRequestRepository;
    private final MemberRepository memberRepository;
    private final CommunityPostRepository communityPostRepository;
    private final NoticeRepository noticeRepository;
    private final CommentRepository commentRepository;
    private final ReportRepository reportRepository;
    private final AuthUtil authUtil;

    // 💡 관리자 권한 신청 (일반 유저용)
    @PostMapping("/requests")
    public ResponseEntity<?> requestAdmin(@RequestBody AdminRequestDto.Create requestDto) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");

        // 중복 신청 확인 (PENDING 상태가 있으면 추가 신청 불가)
        boolean hasPending = adminRequestRepository.findTopByRequesterIdOrderByRequestedAtDesc(memberId)
                .map(req -> req.getStatus() == AdminRequest.RequestStatus.PENDING)
                .orElse(false);
        
        if (hasPending) return ResponseEntity.badRequest().body("이미 대기 중인 신청 건이 있습니다.");

        Member requester = memberRepository.findById(memberId).orElseThrow();
        AdminRequest adminRequest = AdminRequest.builder()
                .requester(requester)
                .reason(requestDto.getReason())
                .build();

        adminRequestRepository.save(adminRequest);
        return ResponseEntity.ok("관리자 권한 신청이 완료되었습니다.");
    }

    // 💡 승인 대기 목록 조회 (SUPER_ADMIN 전용)
    @GetMapping("/requests")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<List<AdminRequestDto.Response>> getPendingRequests() {
        List<AdminRequestDto.Response> responses = adminRequestRepository.findAllByStatusOrderByRequestedAtDesc(AdminRequest.RequestStatus.PENDING).stream()
                .map(AdminRequestDto.Response::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    // 💡 신청 승인 (SUPER_ADMIN 전용)
    @PostMapping("/requests/{id}/approve")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> approveRequest(@PathVariable Long id) {
        AdminRequest adminRequest = adminRequestRepository.findById(id).orElseThrow();
        if (adminRequest.getStatus() != AdminRequest.RequestStatus.PENDING) {
            return ResponseEntity.badRequest().body("이미 처리된 신청 건입니다.");
        }

        adminRequest.approve();
        Member requester = adminRequest.getRequester();
        requester.setRole(MemberRole.ADMIN); // 💡 역할 변경
        
        adminRequestRepository.save(adminRequest);
        memberRepository.save(requester);
        
        return ResponseEntity.ok(requester.getName() + " 유저가 ADMIN으로 승인되었습니다.");
    }

    // 💡 신청 거절 (SUPER_ADMIN 전용)
    @PostMapping("/requests/{id}/reject")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> rejectRequest(@PathVariable Long id) {
        AdminRequest adminRequest = adminRequestRepository.findById(id).orElseThrow();
        if (adminRequest.getStatus() != AdminRequest.RequestStatus.PENDING) {
            return ResponseEntity.badRequest().body("이미 처리된 신청 건입니다.");
        }

        adminRequest.reject();
        adminRequestRepository.save(adminRequest);
        
        return ResponseEntity.ok("신청이 거절되었습니다.");
    }

    // 💡 관리자 게시물 삭제 (소프트 딜리트)
    @DeleteMapping("/posts/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<?> deletePostByAdmin(@PathVariable Long id, @RequestBody java.util.Map<String, String> body) {
        String reason = body.get("reason");
        CommunityPost post = communityPostRepository.findById(id).orElse(null);
        if (post == null) return ResponseEntity.notFound().build();

        post.deleteByAdmin(reason);
        communityPostRepository.save(post);
        return ResponseEntity.ok("게시글이 관리자에 의해 삭제되었습니다.");
    }

    // 💡 관리자 게시물 복구
    @PostMapping("/posts/{id}/restore")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<?> restorePostByAdmin(@PathVariable Long id) {
        CommunityPost post = communityPostRepository.findById(id).orElse(null);
        if (post == null) return ResponseEntity.notFound().build();

        post.restoreByAdmin();
        communityPostRepository.save(post);
        return ResponseEntity.ok("게시글이 성공적으로 복구되었습니다.");
    }

    // 💡 관리자 댓글 삭제 (소프트 딜리트)
    @DeleteMapping("/comments/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<?> deleteCommentByAdmin(@PathVariable Long id, @RequestBody java.util.Map<String, String> body) {
        String reason = body.get("reason");
        Comment comment = commentRepository.findById(id).orElse(null);
        if (comment == null) return ResponseEntity.notFound().build();

        comment.deleteByAdmin(reason);
        if (comment.getCommunityPost() != null) {
            CommunityPost post = comment.getCommunityPost();
            post.decrementCommentCount();
            communityPostRepository.save(post);
        } else if (comment.getNotice() != null) {
            Notice notice = comment.getNotice();
            notice.decrementCommentCount();
            noticeRepository.save(notice);
        }
        commentRepository.save(comment);
        return ResponseEntity.ok("댓글이 관리자에 의해 삭제되었습니다.");
    }

    // 💡 누적 신고 목록 조회 (ADMIN, SUPER_ADMIN 전용)
    @GetMapping("/reports")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<AdminReportSummaryResponse>> getReportedTargets() {
        List<Object[]> groupedReports = reportRepository.findReportCountsGroupedByTarget();
        List<AdminReportSummaryResponse> responses = groupedReports.stream()
                .map(row -> {
                    Report.TargetType targetType = (Report.TargetType) row[0];
                    Long targetId = (Long) row[1];
                    Long count = (Long) row[2];

                    String title = "";
                    String content = "";
                    String authorName = "";
                    Long authorId = null;
                    boolean isAuthorSuspended = false;
                    boolean isDeleted = false;
                    String deletionReason = "";

                    if (targetType == Report.TargetType.POST) {
                        CommunityPost post = communityPostRepository.findById(targetId).orElse(null);
                        if (post != null) {
                            title = post.getTitle();
                            content = post.getContent();
                            authorName = post.isAnonymous() ? "익명" : post.getMember().getName();
                            authorId = post.getMember().getId();
                            isAuthorSuspended = post.getMember().isSuspended();
                            isDeleted = post.isDeleted();
                            deletionReason = post.getDeletionReason();
                        } else {
                            title = "존재하지 않는 게시글";
                            content = "삭제되었거나 존재하지 않는 게시글입니다.";
                        }
                    } else if (targetType == Report.TargetType.COMMENT) {
                        Comment comment = commentRepository.findById(targetId).orElse(null);
                        if (comment != null) {
                            title = "댓글";
                            content = comment.getContent();
                            authorName = comment.getMember().getName();
                            authorId = comment.getMember().getId();
                            isAuthorSuspended = comment.getMember().isSuspended();
                            isDeleted = comment.isDeleted();
                            deletionReason = comment.getDeletionReason();
                        } else {
                            title = "존재하지 않는 댓글";
                            content = "삭제되었거나 존재하지 않는 댓글입니다.";
                        }
                    }

                    List<String> reasons = reportRepository.findAllByTargetTypeAndTargetId(targetType, targetId).stream()
                            .map(Report::getReason)
                            .collect(Collectors.toList());

                    return AdminReportSummaryResponse.builder()
                            .targetType(targetType.name())
                            .targetId(targetId)
                            .reportCount(count)
                            .title(title)
                            .content(content)
                            .authorName(authorName)
                            .authorId(authorId)
                            .isAuthorSuspended(isAuthorSuspended)
                            .isDeleted(isDeleted)
                            .deletionReason(deletionReason)
                            .reasons(reasons)
                            .build();
                })
                .collect(Collectors.toList());

        return ResponseEntity.ok(responses);
    }

    // 💡 신고 기각 및 대상 복구 (ADMIN, SUPER_ADMIN 전용)
    @PostMapping("/reports/dismiss")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<?> dismissReport(@RequestBody ReportDismissRequest request) {
        Report.TargetType targetType;
        try {
            targetType = Report.TargetType.valueOf(request.getTargetType().toUpperCase());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body("올바르지 않은 대상 타입입니다.");
        }

        Long targetId = request.getTargetId();

        // 1. 신고 내역 삭제
        reportRepository.deleteByTargetTypeAndTargetId(targetType, targetId);

        // 2. 대상 복구 (소프트 딜리트 상태인 경우 복구)
        if (targetType == Report.TargetType.POST) {
            CommunityPost post = communityPostRepository.findById(targetId).orElse(null);
            if (post != null && post.isDeleted()) {
                post.restoreByAdmin();
                communityPostRepository.save(post);
            }
        } else if (targetType == Report.TargetType.COMMENT) {
            Comment comment = commentRepository.findById(targetId).orElse(null);
            if (comment != null && comment.isDeleted()) {
                comment.restoreByAdmin();
                if (comment.getCommunityPost() != null) {
                    CommunityPost post = comment.getCommunityPost();
                    post.incrementCommentCount();
                    communityPostRepository.save(post);
                } else if (comment.getNotice() != null) {
                    Notice notice = comment.getNotice();
                    notice.incrementCommentCount();
                    noticeRepository.save(notice);
                }
                commentRepository.save(comment);
            }
        }

        return ResponseEntity.ok("신고가 기각되고 대상이 복구되었습니다.");
    }

    @Data
    public static class ReportDismissRequest {
        private String targetType;
        private Long targetId;
    }

    // 💡 통계 및 DTO 클래스들
    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AdminReportSummaryResponse {
        private String targetType;
        private Long targetId;
        private Long reportCount;
        private String title;
        private String content;
        private String authorName;
        private Long authorId;
        @Getter(AccessLevel.NONE)
        private boolean isAuthorSuspended;
        @Getter(AccessLevel.NONE)
        private boolean isDeleted;
        private String deletionReason;
        private List<String> reasons;

        @JsonProperty("isAuthorSuspended")
        public boolean isAuthorSuspended() {
            return isAuthorSuspended;
        }

        @JsonProperty("isDeleted")
        public boolean isDeleted() {
            return isDeleted;
        }
    }

    public static class AdminRequestDto {
        
        @Data
        @NoArgsConstructor
        @AllArgsConstructor
        public static class Create {
            private String reason;
        }

        @Data
        @Builder
        @NoArgsConstructor
        @AllArgsConstructor
        public static class Response {
            private Long id;
            private String requesterName;
            private String loginId;
            private String reason;
            private String status;
            private String requestedAt;

            public static Response from(AdminRequest request) {
                return Response.builder()
                        .id(request.getId())
                        .requesterName(request.getRequester().getName())
                        .loginId(request.getRequester().getLoginId())
                        .reason(request.getReason())
                        .status(request.getStatus().name())
                        .requestedAt(request.getRequestedAt().toString())
                        .build();
            }
        }
    }
}
