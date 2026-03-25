package com.ync.ysync.repository;

import com.ync.ysync.domain.Notice;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface NoticeRepository extends JpaRepository<Notice, Long> {
    List<Notice> findAllByOrderByIsPinnedDescCreatedAtDesc();
    
    // 💡 제목(title) 또는 내용(content)에 키워드가 포함된 공지사항을 찾아 최신순으로 반환합니다.
    // 대소문자를 구분하지 않도록 IgnoreCase를 사용했습니다.
    List<Notice> findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByIsPinnedDescCreatedAtDesc(String title, String content);

    // 💡 특정 작성자가 쓴 공지사항을 최신순으로 조회합니다. (마이페이지용)
    List<Notice> findAllByAuthorIdOrderByIsPinnedDescCreatedAtDesc(Long authorId);
}
