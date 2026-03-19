package com.ync.ysync.repository;

import com.ync.ysync.domain.Comment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findAllByNoticeIdOrderByCreatedAtAsc(Long noticeId);
    List<Comment> findAllByCommunityPostIdOrderByCreatedAtAsc(Long communityPostId);
    
    // 💡 특정 회원이 작성한 댓글 목록을 조회합니다.
    List<Comment> findAllByMemberIdOrderByCreatedAtDesc(Long memberId);
}
