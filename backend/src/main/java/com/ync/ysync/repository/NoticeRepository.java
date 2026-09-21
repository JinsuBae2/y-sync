package com.ync.ysync.repository;

import com.ync.ysync.domain.Notice;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface NoticeRepository extends JpaRepository<Notice, Long> {
    @Modifying
    @Query("UPDATE Notice n SET n.commentCount = n.commentCount + 1 WHERE n.id = :id")
    int incrementCommentCount(@Param("id") Long id);

    @Modifying
    @Query("UPDATE Notice n SET n.commentCount = CASE WHEN n.commentCount > 0 THEN n.commentCount - 1 ELSE 0 END WHERE n.id = :id")
    int decrementCommentCount(@Param("id") Long id);

    List<Notice> findAllByOrderByIsPinnedDescCreatedAtDesc();
    
    // 💡 페이징을 지원하는 전체 조회 쿼리 추가
    Page<Notice> findAllByOrderByIsPinnedDescCreatedAtDesc(Pageable pageable);
    
    // 💡 제목(title) 또는 내용(content)에 키워드가 포함된 공지사항을 찾아 최신순으로 반환합니다.
    List<Notice> findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByIsPinnedDescCreatedAtDesc(String title, String content);

    // 💡 페이징을 지원하는 키워드 검색 쿼리 추가
    Page<Notice> findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByIsPinnedDescCreatedAtDesc(String title, String content, Pageable pageable);

    // 💡 특정 작성자가 쓴 공지사항을 최신순으로 조회합니다. (마이페이지용)
    List<Notice> findAllByAuthorIdOrderByIsPinnedDescCreatedAtDesc(Long authorId);

    // 💡 특정 기간(예: 조회하려는 월)에 걸쳐 있는 일정이 등록된 공지사항을 조회합니다.
    List<Notice> findAllByEventStartDateLessThanEqualAndEventEndDateGreaterThanEqual(java.time.LocalDate endDate, java.time.LocalDate startDate);


    // 💡 조회수는 DB에서 직접 올립니다. 엔티티 필드를 읽어 +1 하고 저장하면 두 사람이 동시에 열었을 때
    //    둘 다 같은 값을 읽어 1만 증가합니다(lost update). 댓글 수가 이미 쓰고 있는 방식과 같습니다.
    //    clearAutomatically로 영속성 컨텍스트를 비워, 직후 조회가 갱신된 값을 읽게 합니다.
    @Modifying(clearAutomatically = true)
    @Query("UPDATE Notice n SET n.viewCount = n.viewCount + 1 WHERE n.id = :id")
    int incrementViewCount(@Param("id") Long id);

    // ==========================================
    // 공지 피드 — 커서 페이징
    //
    // 💡 필터 두 개는 null 대신 "무필터 값"으로 표현합니다.
    //    - grade: `Grade.ALL`이면 필터하지 않습니다. 그 외에는 전체 공지(ALL)와 해당 학년만 봅니다.
    //      프론트가 하던 `targetGrade == 'ALL' || targetGrade == selected`와 같은 의미입니다.
    //    - keyword: 빈 문자열이면 필터하지 않습니다.
    //    JPQL의 `:param IS NULL` 비교는 파라미터 타입 추론이 흔들릴 수 있어 피했습니다.
    //
    // 💡 정렬은 `createdAt DESC, id DESC`입니다. createdAt은 UNIQUE가 아니라서, 같은 시각에
    //    두 건이 들어오면 id 없이는 커서가 행을 건너뛰거나 중복시킵니다.
    // ==========================================

    @Query("""
            SELECT n FROM Notice n
            WHERE n.isPinned = :pinned
              AND (:grade = com.ync.ysync.domain.Grade.ALL
                   OR n.targetGrade = com.ync.ysync.domain.Grade.ALL
                   OR n.targetGrade = :grade)
              AND (:keyword = ''
                   OR LOWER(n.title) LIKE LOWER(CONCAT('%', :keyword, '%'))
                   OR LOWER(n.content) LIKE LOWER(CONCAT('%', :keyword, '%')))
            ORDER BY n.createdAt DESC, n.id DESC
            """)
    List<Notice> findFeedFirstPage(@Param("pinned") boolean pinned,
                                   @Param("grade") com.ync.ysync.domain.Grade grade,
                                   @Param("keyword") String keyword,
                                   Pageable pageable);

    @Query("""
            SELECT n FROM Notice n
            WHERE n.isPinned = :pinned
              AND (:grade = com.ync.ysync.domain.Grade.ALL
                   OR n.targetGrade = com.ync.ysync.domain.Grade.ALL
                   OR n.targetGrade = :grade)
              AND (:keyword = ''
                   OR LOWER(n.title) LIKE LOWER(CONCAT('%', :keyword, '%'))
                   OR LOWER(n.content) LIKE LOWER(CONCAT('%', :keyword, '%')))
              AND (n.createdAt < :cursorCreatedAt
                   OR (n.createdAt = :cursorCreatedAt AND n.id < :cursorId))
            ORDER BY n.createdAt DESC, n.id DESC
            """)
    List<Notice> findFeedAfterCursor(@Param("pinned") boolean pinned,
                                     @Param("grade") com.ync.ysync.domain.Grade grade,
                                     @Param("keyword") String keyword,
                                     @Param("cursorCreatedAt") java.time.LocalDateTime cursorCreatedAt,
                                     @Param("cursorId") Long cursorId,
                                     Pageable pageable);

    /** 💡 같은 필터 조건에서 가장 최근 공지의 id입니다. 클라이언트가 새 공지 감지 기준으로 들고 다닙니다. */
    @Query("""
            SELECT MAX(n.id) FROM Notice n
            WHERE (:grade = com.ync.ysync.domain.Grade.ALL
                   OR n.targetGrade = com.ync.ysync.domain.Grade.ALL
                   OR n.targetGrade = :grade)
              AND (:keyword = ''
                   OR LOWER(n.title) LIKE LOWER(CONCAT('%', :keyword, '%'))
                   OR LOWER(n.content) LIKE LOWER(CONCAT('%', :keyword, '%')))
            """)
    Long findLatestId(@Param("grade") com.ync.ysync.domain.Grade grade,
                      @Param("keyword") String keyword);

    /** 💡 고정 여부와 무관하게 셉니다. 스크롤 도중 올라온 고정 공지도 "새 공지"이기 때문입니다. */
    @Query("""
            SELECT COUNT(n) FROM Notice n
            WHERE n.id > :sinceId
              AND (:grade = com.ync.ysync.domain.Grade.ALL
                   OR n.targetGrade = com.ync.ysync.domain.Grade.ALL
                   OR n.targetGrade = :grade)
              AND (:keyword = ''
                   OR LOWER(n.title) LIKE LOWER(CONCAT('%', :keyword, '%'))
                   OR LOWER(n.content) LIKE LOWER(CONCAT('%', :keyword, '%')))
            """)
    long countNewerThan(@Param("sinceId") Long sinceId,
                        @Param("grade") com.ync.ysync.domain.Grade grade,
                        @Param("keyword") String keyword);
}
