package com.ync.ysync.repository;

import com.ync.ysync.domain.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface MemberRepository extends JpaRepository<Member, Long> {
    Optional<Member> findByLoginId(String loginId);
    List<Member> findAllByLoginIdIn(Collection<String> loginIds);
    Optional<Member> findByEmail(String email);
    Optional<Member> findBySocialIdAndProvider(String socialId, com.ync.ysync.domain.AuthProvider provider);
    Page<Member> findByLoginIdContainingOrNameContaining(String loginId, String name, Pageable pageable);

    // 💡 관리자 회원 목록은 사전 등록 명단을 겸하므로 탈퇴 처리된 계정을 보여주지 않습니다.
    //    행 자체는 글·댓글의 작성자로 남아 있습니다.
    @org.springframework.data.jpa.repository.Query("select m from Member m where m.withdrawnAt is null")
    Page<Member> findAllNotWithdrawn(Pageable pageable);

    @org.springframework.data.jpa.repository.Query("select m from Member m where m.withdrawnAt is null "
            + "and (m.loginId like %:search% or m.name like %:search%)")
    Page<Member> searchNotWithdrawn(@org.springframework.data.repository.query.Param("search") String search,
                                    Pageable pageable);

    @org.springframework.data.jpa.repository.Query("select m.fcmToken from Member m where m.isActivated = true and m.noticeEnabled = true and m.fcmToken is not null")
    java.util.List<String> findAllFcmTokensOfActivatedMembers();

    @org.springframework.data.jpa.repository.Query("select m from Member m where m.isActivated = true and m.noticeEnabled = true")
    java.util.List<Member> findAllByIsActivatedTrueAndNoticeEnabledTrue();

    // 학년별 알림 전환 시점을 판단하기 위한 집계입니다. 회원 전체를 메모리로 읽지 않고 DB에서 세어 옵니다.
    // 선택값이 없는 회원은 키가 null인 행으로 돌아옵니다.
    @org.springframework.data.jpa.repository.Query("select m.noticeGradePreference, count(m) from Member m where m.isActivated = true and m.noticeEnabled = true group by m.noticeGradePreference")
    java.util.List<Object[]> countNoticeTargetsByGradePreference();

    // 올해 학년 확인이 필요한(미설정 포함) 알림 대상 회원 수입니다.
    @org.springframework.data.jpa.repository.Query("select count(m) from Member m where m.isActivated = true and m.noticeEnabled = true and (m.noticeGradePreference is null or m.gradeConfirmedYear is null or m.gradeConfirmedYear < :academicYear)")
    long countNoticeTargetsNeedingConfirmation(@org.springframework.data.repository.query.Param("academicYear") int academicYear);

    // 공지 알림 대상 전체 수입니다. 비율 계산의 분모로 씁니다.
    @org.springframework.data.jpa.repository.Query("select count(m) from Member m where m.isActivated = true and m.noticeEnabled = true")
    long countNoticeTargets();
}
