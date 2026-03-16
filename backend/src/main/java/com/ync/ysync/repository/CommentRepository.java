package com.ync.ysync.repository;

import com.ync.ysync.domain.Comment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findAllByNoticeIdOrderByCreatedAtAsc(Long noticeId);
}
