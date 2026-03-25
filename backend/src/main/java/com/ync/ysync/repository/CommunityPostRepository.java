package com.ync.ysync.repository;

import com.ync.ysync.domain.CommunityPost;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

// 💡 커뮤니티 게시글 관련 DB 접근 인터페이스입니다.
public interface CommunityPostRepository extends JpaRepository<CommunityPost, Long> {
    
    // 💡 카테고리별로 필터링하여 최신순으로 조회합니다. (고정글 우선)
    List<CommunityPost> findByCategoryOrderByIsPinnedDescCreatedAtDesc(String category);

    // 💡 전체 목록을 최신순으로 조회합니다. (고정글 우선)
    List<CommunityPost> findAllByOrderByIsPinnedDescCreatedAtDesc();

    // 💡 특정 회원이 작성한 게시글을 최신순으로 조회합니다.
    List<CommunityPost> findAllByMemberIdOrderByCreatedAtDesc(Long memberId);
}
