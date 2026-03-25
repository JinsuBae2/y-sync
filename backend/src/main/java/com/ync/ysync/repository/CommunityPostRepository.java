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

    // 💡 전체 카테고리에서 키워드로 게시글을 검색합니다. (제목 또는 내용에 포함, 대소문자 구분 없음)
    List<CommunityPost> findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByIsPinnedDescCreatedAtDesc(String titleKeyword, String contentKeyword);

    // 💡 특정 카테고리 내에서 키워드로 게시글을 검색합니다. (제목 또는 내용에 포함, 대소문자 구분 없음)
    @org.springframework.data.jpa.repository.Query("SELECT p FROM CommunityPost p WHERE p.category = :category AND (LOWER(p.title) LIKE LOWER(CONCAT('%', :keyword, '%')) OR LOWER(p.content) LIKE LOWER(CONCAT('%', :keyword, '%'))) ORDER BY p.isPinned DESC, p.createdAt DESC")
    List<CommunityPost> searchByCategoryAndKeyword(@org.springframework.data.repository.query.Param("category") String category, @org.springframework.data.repository.query.Param("keyword") String keyword);
}
