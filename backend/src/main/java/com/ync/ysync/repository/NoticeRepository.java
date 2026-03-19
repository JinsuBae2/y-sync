package com.ync.ysync.repository;

import com.ync.ysync.domain.Notice;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface NoticeRepository extends JpaRepository<Notice, Long> {
    List<Notice> findAllByOrderByCreatedAtDesc();
    
    // 💡 제목(title) 또는 내용(content)에 키워드가 포함된 공지사항을 찾아 최신순으로 반환합니다.
    // 대소문자를 구분하지 않도록 IgnoreCase를 사용했습니다.
    List<Notice> findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByCreatedAtDesc(String title, String content);
}
