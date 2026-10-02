package com.ync.ysync.repository;

import com.ync.ysync.domain.CommunityPost;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

// 💡 커뮤니티 게시글 관련 DB 접근 인터페이스입니다.
public interface CommunityPostRepository extends JpaRepository<CommunityPost, Long> {
    @Modifying
    @Query("UPDATE CommunityPost p SET p.commentCount = p.commentCount + 1 WHERE p.id = :id")
    int incrementCommentCount(@Param("id") Long id);

    @Modifying
    @Query("UPDATE CommunityPost p SET p.commentCount = CASE WHEN p.commentCount > 0 THEN p.commentCount - 1 ELSE 0 END WHERE p.id = :id")
    int decrementCommentCount(@Param("id") Long id);
    
    // 💡 카테고리별로 필터링하여 최신순으로 조회합니다. (고정글 우선)
    List<CommunityPost> findByCategoryOrderByIsPinnedDescCreatedAtDesc(String category);

    // 💡 전체 목록을 최신순으로 조회합니다. (고정글 우선)
    List<CommunityPost> findAllByOrderByIsPinnedDescCreatedAtDesc();

    // 💡 특정 회원이 작성한 게시글을 최신순으로 조회합니다.
    List<CommunityPost> findAllByMemberIdOrderByCreatedAtDesc(Long memberId);

    // 💡 전체 카테고리에서 키워드로 게시글을 검색합니다. (제목 또는 내용에 포함, 대소문자 구분 없음)
    List<CommunityPost> findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByIsPinnedDescCreatedAtDesc(String titleKeyword, String contentKeyword);

    // 💡 특정 카테고리 내에서 키워드로 게시글을 검색합니다. (제목 또는 내용에 포함, 대소문자 구분 없음)
    @Query("SELECT p FROM CommunityPost p WHERE p.category = :category AND (LOWER(p.title) LIKE LOWER(CONCAT('%', :keyword, '%')) OR LOWER(p.content) LIKE LOWER(CONCAT('%', :keyword, '%'))) ORDER BY p.isPinned DESC, p.createdAt DESC")
    List<CommunityPost> searchByCategoryAndKeyword(@Param("category") String category, @Param("keyword") String keyword);


    // 💡 조회수는 DB에서 직접 올립니다. 엔티티 필드를 읽어 +1 하고 저장하면 두 사람이 동시에 열었을 때
    //    둘 다 같은 값을 읽어 1만 증가합니다(lost update). 댓글 수가 이미 쓰고 있는 방식과 같습니다.
    //    clearAutomatically로 영속성 컨텍스트를 비워, 직후 조회가 갱신된 값을 읽게 합니다.
    @Modifying(clearAutomatically = true)
    @Query("UPDATE CommunityPost p SET p.viewCount = p.viewCount + 1 WHERE p.id = :id")
    int incrementViewCount(@Param("id") Long id);
}
