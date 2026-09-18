package com.ync.ysync.controller;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List; // 💡 추가
import java.util.stream.Collectors; // 💡 추가

import com.ync.ysync.repository.CommentRepository;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository; // 💡 추가
import com.ync.ysync.config.AuthUtil;
import com.ync.ysync.domain.CommentDeletedBy;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.NoticeGradePreference;
import com.ync.ysync.service.NoticeGradeService;
import com.ync.ysync.service.MemberService;
import lombok.AllArgsConstructor;
import lombok.AccessLevel;
import lombok.Data;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/members")
@RequiredArgsConstructor
public class MemberProfileController {

    private final MemberRepository memberRepository;
    private final CommunityPostRepository communityPostRepository;
    private final CommentRepository commentRepository;
    private final NoticeRepository noticeRepository;
    private final MemberService memberService;
    private final NoticeGradeService noticeGradeService;
    private final AuthUtil authUtil;

    @GetMapping("/me")
    public ResponseEntity<MemberResponse> getMyProfile() {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        int currentAcademicYear = noticeGradeService.currentAcademicYear();
        return memberRepository.findById(memberId)
                .map(member -> ResponseEntity.ok(toMemberResponse(member, currentAcademicYear)))
                .orElse(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
    }

    /**
     * 💡 공지 알림 수신 학년 선택/재확인
     *
     * 인증된 본인의 정보만 수정합니다. 요청 본문에는 대상 회원을 지정하는 값이 없으므로
     * 학번이나 타인의 회원 ID를 바꿔 다른 사람의 설정을 수정할 수 없습니다.
     */
    @PutMapping("/me/notice-grade")
    public ResponseEntity<?> updateNoticeGrade(@RequestBody NoticeGradeRequest request) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        try {
            Member member = noticeGradeService.updateOwnPreference(memberId, request.getNoticeGradePreference());
            return ResponseEntity.ok(toMemberResponse(member, noticeGradeService.currentAcademicYear()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(java.util.Map.of("message", e.getMessage()));
        }
    }

    private MemberResponse toMemberResponse(Member member, int currentAcademicYear) {
        return new MemberResponse(
                member.getId(),
                member.getLoginId(),
                member.getName(),
                member.getRole().name(),
                member.isNoticeEnabled(),
                member.isCommentEnabled(),
                member.getNoticeGradePreference(),
                member.getGradeConfirmedYear(),
                currentAcademicYear,
                noticeGradeService.confirmationRequired(member, currentAcademicYear)
        );
    }

    @GetMapping("/settings")
    public ResponseEntity<SettingsResponse> getSettings() {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        return memberRepository.findById(memberId)
                .map(member -> ResponseEntity.ok(new SettingsResponse(member.isNoticeEnabled(), member.isCommentEnabled())))
                .orElse(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
    }

    @PutMapping("/settings")
    public ResponseEntity<SettingsResponse> updateSettings(@RequestBody SettingsRequest request) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        memberService.updateNotificationSettings(memberId, request.isNoticeEnabled(), request.isCommentEnabled());
        return ResponseEntity.ok(new SettingsResponse(request.isNoticeEnabled(), request.isCommentEnabled()));
    }

    // 💡 내가 작성한 커뮤니티 게시글 목록 조회
    @GetMapping("/me/posts")
    public ResponseEntity<List<CommunityController.CommunityResponse>> getMyPosts() {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        List<CommunityController.CommunityResponse> responses = communityPostRepository.findAllByMemberIdOrderByCreatedAtDesc(memberId).stream()
                .map(CommunityController.CommunityResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    // 💡 내가 작성한 공지사항 목록 조회 (관리자 전용)
    @GetMapping("/me/notices")
    public ResponseEntity<List<NoticeResponse>> getMyNotices() {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        List<NoticeResponse> responses = noticeRepository.findAllByAuthorIdOrderByIsPinnedDescCreatedAtDesc(memberId).stream()
                .map(NoticeResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }



    // 💡 내가 작성한 댓글 목록 조회 (대상 게시물 정보 포함)
    @GetMapping("/me/comments")
    public ResponseEntity<List<MyCommentResponse>> getMyComments() {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        List<MyCommentResponse> responses = commentRepository.findAllByMemberIdOrderByCreatedAtDesc(memberId).stream()
                .filter(comment -> !comment.isDeleted()
                        || comment.getDeletedBy() == CommentDeletedBy.ADMIN
                        || (comment.getDeletedBy() == null
                        && comment.getDeletionReason() != null
                        && !comment.getDeletionReason().isBlank()))
                .map(comment -> {
                    String postTitle = "";
                    String category = "";
                    Long postId = null;

                    if (comment.getCommunityPost() != null) {
                        postTitle = comment.getCommunityPost().getTitle();
                        category = comment.getCommunityPost().getCategory();
                        postId = comment.getCommunityPost().getId();
                    } else if (comment.getNotice() != null) {
                        postTitle = comment.getNotice().getTitle();
                        category = "NOTICE";
                        postId = comment.getNotice().getId();
                    }

                    return new MyCommentResponse(
                            comment.getId(),
                            comment.getContent(),
                            postTitle,
                            category,
                            postId,
                            comment.getCreatedAt().toString(),
                            comment.isDeleted(),
                            comment.getDeletionReason(),
                            comment.getDeletedBy()
                    );
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    @Data
    @AllArgsConstructor
    public static class MemberResponse {
        private Long id;
        private String loginId;
        private String name;
        private String role;
        private boolean noticeEnabled;
        private boolean commentEnabled;
        // 💡 미설정은 null로 내려가며, 사용자가 명시적으로 고른 GENERAL_ONLY와 구분됩니다.
        private NoticeGradePreference noticeGradePreference;
        private Integer gradeConfirmedYear;
        private int currentAcademicYear;
        private boolean gradeConfirmationRequired;
    }

    @Data
    public static class NoticeGradeRequest {
        // 💡 허용된 네 값만 역직렬화되며, 다른 문자열은 요청 단계에서 거부됩니다.
        private NoticeGradePreference noticeGradePreference;
    }

    @Data
    public static class SettingsRequest {
        private boolean noticeEnabled;
        private boolean commentEnabled;
    }

    @Data
    @AllArgsConstructor
    public static class SettingsResponse {
        private boolean noticeEnabled;
        private boolean commentEnabled;
    }

    @Getter
    @AllArgsConstructor
    public static class MyCommentResponse {
        private Long id;
        private String content;
        private String postTitle;
        private String category;
        private Long postId;
        private String createdAt;
        @Getter(AccessLevel.NONE)
        private boolean isDeleted;
        private String deletionReason;
        private CommentDeletedBy deletedBy;

        @JsonProperty("isDeleted")
        public boolean isDeleted() {
            return isDeleted;
        }
    }
}
