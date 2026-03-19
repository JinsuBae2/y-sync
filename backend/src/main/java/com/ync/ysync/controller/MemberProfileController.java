package com.ync.ysync.controller;

import java.util.List; // 💡 추가
import java.util.stream.Collectors; // 💡 추가

import com.ync.ysync.repository.CommentRepository;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository; // 💡 추가
import jakarta.servlet.http.HttpSession;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
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

    @GetMapping("/me")
    public ResponseEntity<MemberResponse> getMyProfile(HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        return memberRepository.findById(memberId)
                .map(member -> ResponseEntity.ok(new MemberResponse(member.getId(), member.getLoginId(), member.getName(), member.getRole().name())))
                .orElse(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
    }

    // 💡 내가 작성한 커뮤니티 게시글 목록 조회
    @GetMapping("/me/posts")
    public ResponseEntity<List<CommunityController.CommunityResponse>> getMyPosts(HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        List<CommunityController.CommunityResponse> responses = communityPostRepository.findAllByMemberIdOrderByCreatedAtDesc(memberId).stream()
                .map(CommunityController.CommunityResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    // 💡 내가 작성한 공지사항 목록 조회 (관리자 전용)
    @GetMapping("/me/notices")
    public ResponseEntity<List<NoticeResponse>> getMyNotices(HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        List<NoticeResponse> responses = noticeRepository.findAllByAuthorIdOrderByCreatedAtDesc(memberId).stream()
                .map(NoticeResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }



    // 💡 내가 작성한 댓글 목록 조회 (대상 게시물 정보 포함)
    @GetMapping("/me/comments")
    public ResponseEntity<List<MyCommentResponse>> getMyComments(HttpSession session) {
        Long memberId = (Long) session.getAttribute("loginMemberId");
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        List<MyCommentResponse> responses = commentRepository.findAllByMemberIdOrderByCreatedAtDesc(memberId).stream()
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
                            comment.getCreatedAt().toString()
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
    }

    @Data
    @AllArgsConstructor
    public static class MyCommentResponse {
        private Long id;
        private String content;
        private String postTitle;
        private String category;
        private Long postId;
        private String createdAt;
    }
}
