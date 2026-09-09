package com.ync.ysync.repository;

import com.ync.ysync.domain.Feedback;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FeedbackRepository extends JpaRepository<Feedback, Long> {
    Page<Feedback> findByReviewed(boolean reviewed, Pageable pageable);
}
