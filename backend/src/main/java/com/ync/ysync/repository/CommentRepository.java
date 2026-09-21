package com.ync.ysync.repository;

import com.ync.ysync.domain.Comment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findAllByNoticeIdOrderByCreatedAtAsc(Long noticeId);
    List<Comment> findAllByCommunityPostIdOrderByCreatedAtAsc(Long communityPostId);
    
    // 💡 특정 회원이 작성한 댓글 목록을 조회합니다.
    List<Comment> findAllByMemberIdOrderByCreatedAtDesc(Long memberId);

    @Query("SELECT c.id FROM Comment c WHERE c.communityPost.id = :communityPostId")
    List<Long> findIdsByCommunityPostId(@Param("communityPostId") Long communityPostId);

    @Query("SELECT c.id FROM Comment c WHERE c.notice.id = :noticeId")
    List<Long> findIdsByNoticeId(@Param("noticeId") Long noticeId);

    // 💡 글을 하드 삭제하기 전에 댓글을 먼저 지웁니다.
    //    comment.parent_id 는 comment 자기 자신을 참조하므로 대댓글을 먼저 지우고 원 댓글을 지웁니다.
    //    대댓글에 다시 답글을 달 수 없도록 CommentService.validateReplyableParent 가 막고 있어 깊이는 2단계입니다.
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM Comment c WHERE c.communityPost.id = :communityPostId AND c.parent IS NOT NULL")
    void deleteRepliesByCommunityPostId(@Param("communityPostId") Long communityPostId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM Comment c WHERE c.communityPost.id = :communityPostId")
    void deleteAllByCommunityPostId(@Param("communityPostId") Long communityPostId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM Comment c WHERE c.notice.id = :noticeId AND c.parent IS NOT NULL")
    void deleteRepliesByNoticeId(@Param("noticeId") Long noticeId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM Comment c WHERE c.notice.id = :noticeId")
    void deleteAllByNoticeId(@Param("noticeId") Long noticeId);
}
