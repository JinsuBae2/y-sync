package com.ync.ysync.repository;

import com.ync.ysync.domain.Notice;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface NoticeRepository extends JpaRepository<Notice, Long> {
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
}
