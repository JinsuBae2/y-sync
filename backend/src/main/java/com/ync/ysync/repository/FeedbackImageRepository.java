package com.ync.ysync.repository;

import com.ync.ysync.domain.FeedbackImage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.util.List;

public interface FeedbackImageRepository extends JpaRepository<FeedbackImage, Long> {
    // 💡 목록에서는 이미지 바이너리를 읽지 않습니다.
    @Query("select i.id from FeedbackImage i where i.feedbackId = :feedbackId order by i.id")
    List<Long> findIdsByFeedbackId(Long feedbackId);
}
