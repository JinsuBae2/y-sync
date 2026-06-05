package com.ync.ysync.repository;

import com.ync.ysync.domain.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import java.util.Optional;

public interface MemberRepository extends JpaRepository<Member, Long> {
    Optional<Member> findByLoginId(String loginId);
    Optional<Member> findBySocialIdAndProvider(String socialId, com.ync.ysync.domain.AuthProvider provider);
    Page<Member> findByLoginIdContainingOrNameContaining(String loginId, String name, Pageable pageable);
}
