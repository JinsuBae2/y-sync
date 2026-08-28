package com.ync.ysync.service;

import com.ync.ysync.domain.Comment;
import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.repository.CommentRepository;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import com.ync.ysync.event.CommentCreatedEvent;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommentService {

    private final CommentRepository commentRepository;
    private final NoticeRepository noticeRepository;
    private final CommunityPostRepository communityPostRepository;
    private final MemberRepository memberRepository;
    private final ApplicationEventPublisher eventPublisher; // 💡 비동기 알림 이벤트 발행자

    public Comment getComment(Long commentId) {
        return commentRepository.findById(commentId)
                .orElseThrow(() -> new IllegalArgumentException("해당 댓글이 존재하지 않습니다."));
    }

    @Transactional
    public Comment createComment(Long noticeId, Long memberId, String content, Long parentId) {
        Notice notice = noticeRepository.findById(noticeId)
                .orElseThrow(() -> new IllegalArgumentException("해당 공지사항이 존재하지 않습니다."));
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        Comment parent = null;
        if (parentId != null) {
            parent = commentRepository.findById(parentId)
                    .orElseThrow(() -> new IllegalArgumentException("부모 댓글을 찾을 수 없습니다."));
            validateNoticeParent(parent, noticeId);
        }

        Comment comment = Comment.builder()
                .content(content)
                .notice(notice)
                .member(member)
                .parent(parent) // 💡 대댓글 parent 설정
                .build();

        Comment savedComment = commentRepository.save(comment);

        // 💡 [Bug4 Fix] 댓글 수 증가 반영 및 명시적 DB 저장 (트랜잭션 플러시 보장)
        noticeRepository.incrementCommentCount(noticeId);

        // 💡 트랜잭션이 활성화된 상태에서 Lazy Loading 없이 대상 유저 정보를 꺼냄 (지연 로딩 에러 원천 방지)
        Member author = notice.getAuthor();
        if (author != null) {
            eventPublisher.publishEvent(new CommentCreatedEvent(
                    this,
                    author.getId(),
                    author.getFcmToken(),
                    author.isCommentEnabled(),
                    memberId,
                    "NOTICE",
                    notice.getId(),
                    content
            ));
        }

        return savedComment;
    }

    @Transactional
    public Comment createCommunityComment(Long communityPostId, Long memberId, String content, Long parentId) {
        CommunityPost post = communityPostRepository.findById(communityPostId)
                .orElseThrow(() -> new IllegalArgumentException("해당 게시글이 존재하지 않습니다."));
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        Comment parent = null;
        if (parentId != null) {
            parent = commentRepository.findById(parentId)
                    .orElseThrow(() -> new IllegalArgumentException("부모 댓글을 찾을 수 없습니다."));
            validateCommunityParent(parent, communityPostId);
        }

        Comment comment = Comment.builder()
                .content(content)
                .communityPost(post)
                .member(member)
                .parent(parent) // 💡 대댓글 parent 설정
                .build();

        Comment savedComment = commentRepository.save(comment);

        // 💡 [Bug4 Fix] 댓글 수 증가 반영 및 명시적 DB 저장 (트랜잭션 플러시 보장)
        communityPostRepository.incrementCommentCount(communityPostId);

        // 💡 트랜잭션이 활성화된 상태에서 Lazy Loading 없이 대상 유저 정보를 꺼냄 (지연 로딩 에러 원천 방지)
        Member postAuthor = post.getMember();
        if (postAuthor != null) {
            eventPublisher.publishEvent(new CommentCreatedEvent(
                    this,
                    postAuthor.getId(),
                    postAuthor.getFcmToken(),
                    postAuthor.isCommentEnabled(),
                    memberId,
                    "COMMUNITY",
                    post.getId(),
                    content
            ));
        }

        return savedComment;
    }

    private void validateNoticeParent(Comment parent, Long noticeId) {
        if (parent.getNotice() == null || !parent.getNotice().getId().equals(noticeId)) {
            throw new IllegalArgumentException("같은 공지사항의 댓글에만 답글을 작성할 수 있습니다.");
        }
        validateReplyableParent(parent);
    }

    private void validateCommunityParent(Comment parent, Long communityPostId) {
        if (parent.getCommunityPost() == null || !parent.getCommunityPost().getId().equals(communityPostId)) {
            throw new IllegalArgumentException("같은 게시물의 댓글에만 답글을 작성할 수 있습니다.");
        }
        validateReplyableParent(parent);
    }

    private void validateReplyableParent(Comment parent) {
        if (parent.getParent() != null) {
            throw new IllegalArgumentException("답글에는 추가 답글을 작성할 수 없습니다.");
        }
        if (parent.isDeleted()) {
            throw new IllegalArgumentException("삭제된 댓글에는 답글을 작성할 수 없습니다.");
        }
    }

    // 💡 학사 공지사항 대댓글 계층형 DTO 조립 조회
    public List<com.ync.ysync.controller.CommentResponse> getCommentTreeByNoticeId(Long noticeId) {
        List<Comment> comments = commentRepository.findAllByNoticeIdOrderByCreatedAtAsc(noticeId);
        return convertToTree(comments);
    }

    // 💡 커뮤니티 게시글 대댓글 계층형 DTO 조립 조회
    public List<com.ync.ysync.controller.CommentResponse> getCommentTreeByCommunityPostId(Long communityPostId) {
        List<Comment> comments = commentRepository.findAllByCommunityPostIdOrderByCreatedAtAsc(communityPostId);
        return convertToTree(comments);
    }

    // 💡 일차원 댓글 리스트를 트리 구조(계층형) DTO 리스트로 가공하는 공용 비즈니스 로직
    private List<com.ync.ysync.controller.CommentResponse> convertToTree(List<Comment> comments) {
        List<com.ync.ysync.controller.CommentResponse> result = new java.util.ArrayList<>();
        java.util.Map<Long, com.ync.ysync.controller.CommentResponse> map = new java.util.HashMap<>();

        // 1단계: DTO로 전부 변환하여 맵에 저장
        for (Comment comment : comments) {
            com.ync.ysync.controller.CommentResponse response = com.ync.ysync.controller.CommentResponse.from(comment);
            map.put(comment.getId(), response);
            if (comment.getParent() == null) {
                result.add(response); // 루트 댓글
            }
        }

        // 2단계: 자식 댓글들을 부모 DTO의 children에 매핑
        for (Comment comment : comments) {
            if (comment.getParent() != null) {
                com.ync.ysync.controller.CommentResponse parentResponse = map.get(comment.getParent().getId());
                if (parentResponse != null) {
                    parentResponse.getChildren().add(map.get(comment.getId()));
                }
            }
        }

        return result;
    }

    @Transactional
    public void deleteComment(Long commentId, Long memberId, MemberRole role) {
        Comment comment = getComment(commentId);
        
        // 관리자 삭제는 삭제 사유가 필요한 전용 API에서 처리합니다.
        if (!comment.getMember().getId().equals(memberId)) {
            if (role == MemberRole.ADMIN || role == MemberRole.SUPER_ADMIN) {
                throw new IllegalArgumentException("관리자 댓글 삭제 API를 이용해 주세요.");
            }
            throw new IllegalArgumentException("해당 댓글에 대한 권한이 없습니다.");
        }

        if (comment.isDeleted()) {
            return;
        }
        
        if (comment.getCommunityPost() != null) {
            comment.deleteByAuthor();
            communityPostRepository.decrementCommentCount(comment.getCommunityPost().getId());
        } else if (comment.getNotice() != null) {
            comment.deleteByAuthor();
            noticeRepository.decrementCommentCount(comment.getNotice().getId());
        }

    }

    @Transactional
    public void deleteCommentByAdmin(Long commentId, String reason) {
        // TODO: 댓글 조회
        Comment comment = getComment(commentId);
        // TODO: 이미 삭제됐으면 반환
        if (comment.isDeleted()) {
            return;
        }
        // TODO: 관리자 소프트 삭제
        comment.deleteByAdmin(reason);
        // TODO: 게시글 또는 공지 댓글 수 감소
        if (comment.getCommunityPost() != null) {
            communityPostRepository.decrementCommentCount(comment.getCommunityPost().getId());
        } else if (comment.getNotice() != null) {
            noticeRepository.decrementCommentCount(comment.getNotice().getId());
        }
        commentRepository.save(comment);
    }
}
