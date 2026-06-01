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
    private final FCMService fcmService; // 💡 FCM 추가

    public List<Comment> getCommentsByNoticeId(Long noticeId) {
        return commentRepository.findAllByNoticeIdOrderByCreatedAtAsc(noticeId);
    }

    public List<Comment> getCommentsByCommunityPostId(Long communityPostId) {
        return commentRepository.findAllByCommunityPostIdOrderByCreatedAtAsc(communityPostId);
    }

    public Comment getComment(Long commentId) {
        return commentRepository.findById(commentId)
                .orElseThrow(() -> new IllegalArgumentException("해당 댓글이 존재하지 않습니다."));
    }

    @Transactional
    public Comment createComment(Long noticeId, Long memberId, String content) {
        Notice notice = noticeRepository.findById(noticeId)
                .orElseThrow(() -> new IllegalArgumentException("해당 공지사항이 존재하지 않습니다."));
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        Comment comment = Comment.builder()
                .content(content)
                .notice(notice)
                .member(member)
                .build();

        Comment savedComment = commentRepository.save(comment);

        // 💡 [Bug4 Fix] 댓글 수 증가 반영 및 명시적 DB 저장 (트랜잭션 플러시 보장)
        notice.incrementCommentCount();
        noticeRepository.save(notice);

        // 💡 게시글 작성자에게 새 댓글 알림 발송 (단, 내가 내 글에 단 댓글은 제외)
        Member author = notice.getAuthor();
        if (author.getFcmToken() != null && !author.getId().equals(memberId) && author.isCommentEnabled()) {
            log.info("[FCM] 공지사항 댓글 알림 발송 - Notice ID: {}, 수신자: {}, Token: {}...", notice.getId(), author.getName(), author.getFcmToken().substring(0, Math.min(author.getFcmToken().length(), 20)));
            java.util.Map<String, String> data = new java.util.HashMap<>();
            data.put("targetType", "NOTICE");
            data.put("targetId", String.valueOf(notice.getId()));
            fcmService.sendNotificationToToken(author.getFcmToken(), "내 작성글에 새로운 댓글", "방금 누군가 댓글을 남겼어요!", data);
        } else {
            log.info("[FCM] 공지사항 댓글 알림 Skip - Notice ID: {}, 사유: fcmToken={}, 본인글={}, commentEnabled={}",
                    notice.getId(), author.getFcmToken() != null, author.getId().equals(memberId), author.isCommentEnabled());
        }

        return savedComment;
    }

    @Transactional
    public Comment createCommunityComment(Long communityPostId, Long memberId, String content) {
        CommunityPost post = communityPostRepository.findById(communityPostId)
                .orElseThrow(() -> new IllegalArgumentException("해당 게시글이 존재하지 않습니다."));
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        Comment comment = Comment.builder()
                .content(content)
                .communityPost(post)
                .member(member)
                .build();

        Comment savedComment = commentRepository.save(comment);

        // 💡 [Bug4 Fix] 댓글 수 증가 반영 및 명시적 DB 저장 (트랜잭션 플러시 보장)
        post.incrementCommentCount();
        communityPostRepository.save(post);

        // 💡 커뮤니티 글 작성자에게 새 댓글 알림 발송 (단, 내가 내 글에 단 댓글은 제외)
        Member postAuthor = post.getMember();
        if (postAuthor.getFcmToken() != null && !postAuthor.getId().equals(memberId) && postAuthor.isCommentEnabled()) {
            log.info("[FCM] 커뮤니티 댓글 알림 발송 - Post ID: {}, 수신자: {}, Token: {}...", post.getId(), postAuthor.getName(), postAuthor.getFcmToken().substring(0, Math.min(postAuthor.getFcmToken().length(), 20)));
            java.util.Map<String, String> data = new java.util.HashMap<>();
            data.put("targetType", "COMMUNITY");
            data.put("targetId", String.valueOf(post.getId()));
            fcmService.sendNotificationToToken(postAuthor.getFcmToken(), "내 게시글에 새로운 댓글", "방금 누군가 댓글을 남겼어요!", data);
        } else {
            log.info("[FCM] 커뮤니티 댓글 알림 Skip - Post ID: {}, 사유: fcmToken={}, 본인글={}, commentEnabled={}",
                    post.getId(), postAuthor.getFcmToken() != null, postAuthor.getId().equals(memberId), postAuthor.isCommentEnabled());
        }

        return savedComment;
    }

    @Transactional
    public void deleteComment(Long commentId, Long memberId, MemberRole role) {
        Comment comment = getComment(commentId);
        
        // 작성자 본인이거나 ADMIN인 경우에만 삭제 가능
        if (role != MemberRole.ADMIN && !comment.getMember().getId().equals(memberId)) {
            throw new IllegalArgumentException("해당 댓글에 대한 권한이 없습니다.");
        }
        
        if (comment.getCommunityPost() != null) {
            comment.getCommunityPost().decrementCommentCount(); // 💡 게시글 댓글 수 감소
            communityPostRepository.save(comment.getCommunityPost()); // 💡 명시적 DB 저장
        } else if (comment.getNotice() != null) {
            comment.getNotice().decrementCommentCount(); // 💡 공지사항 댓글 수 감소
            noticeRepository.save(comment.getNotice()); // 💡 명시적 DB 저장
        }
        commentRepository.delete(comment);
    }
}
