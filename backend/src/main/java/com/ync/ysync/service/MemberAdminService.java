package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.NoticeGradePreference;
import com.ync.ysync.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 💡 관리자 전용 회원 관리입니다. 조회·사전 등록·수정·탈퇴·차단·계정 초기화를 담당합니다.
 *
 * `MemberService`에서 분리한 이유는 **권한 경계**입니다. 한 클래스에 가입·로그인과 관리자 조작이
 * 함께 있으면 `AdminMemberController`가 `signup()`까지 부를 수 있는 상태가 됩니다.
 * 여기 있는 동작은 전부 되돌리기 어렵거나 권한에 민감하므로 호출 가능한 범위를 좁혀 둡니다.
 *
 * 권한 부여 규칙은 명단 일괄 등록과 공유해야 하므로 {@link MemberRolePolicy}에 있습니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MemberAdminService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;
    private final MemberWithdrawer memberWithdrawer;
    private final MemberVerificationService verificationService;
    private final MemberSignupService signupService;

    /**
     * 전체 회원 목록 페이징 및 이름/학번 검색 조회
     */
    @Transactional(readOnly = true)
    public Page<Member> getMembers(Pageable pageable, String search) {
        // 💡 이 목록은 사전 등록 명단을 겸하므로 탈퇴 처리된 계정은 보여주지 않습니다.
        //    행 자체는 글·댓글의 작성자로 남아 있습니다.
        if (search == null || search.trim().isEmpty()) {
            return memberRepository.findAllNotWithdrawn(pageable);
        }
        return memberRepository.searchNotWithdrawn(search, pageable);
    }

    /**
     * 관리자 단건 사전 등록
     */
    @Transactional
    public Member createMemberByAdmin(String loginId, String name, MemberRole role, MemberRole actorRole) {
        MemberRole requestedRole = role != null ? role : MemberRole.USER;
        MemberRolePolicy.validateAssignment(actorRole, requestedRole);
        // 이미 등록된 학번인 경우
        if (memberRepository.findByLoginId(loginId).isPresent()) {
            throw new IllegalArgumentException("이미 등록되었거나 사용 중인 학번입니다.");
        }

        Member member = Member.builder()
                .loginId(loginId)
                .password(passwordEncoder.encode("TEMP_" + loginId + "_" + System.currentTimeMillis())) // 임시 비밀번호 (로그인
                                                                                                        // 불가능 상태 유도)
                .name(name)
                .role(requestedRole)
                .isActivated(false) // 비활성화 상태로 등록
                .provider(AuthProvider.LOCAL)
                .authType(AuthType.PASSWORD)
                .build();

        log.info("관리자 학생 사전등록 완료 - 학번: {}, 이름: {}", loginId, name);
        return memberRepository.save(member);
    }

    /**
     * 관리자 권한 회원 정보 수정 (이름, 권한)
     */
    @Transactional
    public Member updateMemberByAdmin(Long id, String name, MemberRole role, MemberRole actorRole) {
        return updateMemberByAdmin(id, name, role, actorRole, null, null);
    }

    /**
     * 관리자 권한 회원 정보 수정 (이름, 권한, 공지 알림 수신 학년)
     *
     * 💡 학년은 문의가 들어온 예외 상황을 지원하기 위한 수단이며, 수정 권한은 기존 회원 수정 권한을 그대로 따릅니다.
     *    관리자 수정도 현재 학년도 확인으로 처리하므로 학생에게 같은 학년도 안내가 다시 뜨지 않습니다.
     */
    @Transactional
    public Member updateMemberByAdmin(Long id, String name, MemberRole role, MemberRole actorRole,
                                      NoticeGradePreference noticeGradePreference, Integer academicYear) {
        Member member = findMember(id);

        if (actorRole != MemberRole.SUPER_ADMIN && member.getRole() == MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("ADMIN은 SUPER_ADMIN 계정을 변경할 수 없습니다.");
        }

        if (name != null && !name.trim().isEmpty()) {
            member.setName(name);
        }
        if (role != null && role != member.getRole()) {
            MemberRolePolicy.validateAssignment(actorRole, role);
            member.setRole(role);
            member.setAuthVersion(member.getAuthVersion() + 1);
        }

        if (noticeGradePreference != null) {
            member.setNoticeGradePreference(noticeGradePreference);
            member.setGradeConfirmedYear(academicYear);
        }

        log.info("관리자 회원정보 수정 완료 - ID: {}, 수정된 이름: {}, 권한: {}, 공지 학년: {}",
                id, member.getName(), member.getRole(), member.getNoticeGradePreference());
        return memberRepository.save(member);
    }

    /**
     * 관리자 권한 회원 탈퇴 처리
     *
     * 💡 행을 지우지 않고 익명화합니다. 이유는 {@link MemberWithdrawer} 주석을 보십시오.
     *    요약하면, 글·댓글을 쓴 회원은 FK 때문에 삭제가 실패하고 억지로 지우면 다른 학생의 댓글까지 사라집니다.
     */
    @Transactional
    public void deleteMemberByAdmin(Long id) {
        Member member = findMember(id);
        if (member.getRole() == MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("SUPER_ADMIN 계정은 삭제할 수 없습니다.");
        }
        if (member.isWithdrawn()) {
            throw new IllegalArgumentException("이미 탈퇴 처리된 계정입니다.");
        }

        memberWithdrawer.withdraw(member);
        memberRepository.save(member);

        // 💡 학번은 남기지 않습니다. 지운 개인정보를 로그에 다시 적으면 익명화한 의미가 없습니다.
        log.info("관리자 회원 탈퇴 처리 완료 - ID: {}", id);
    }

    /**
     * 관리자 권한 비밀번호 재설정 안내 발송. 계정 데이터와 권한은 바꾸지 않습니다.
     */
    public void requestPasswordResetByAdmin(Long id) {
        Member member = findMember(id);
        if (member.getRole() == MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("SUPER_ADMIN 계정은 관리자 도구로 재설정할 수 없습니다.");
        }
        if (!member.isActivated()) {
            throw new IllegalArgumentException("가입 대기 계정은 비밀번호를 재설정할 수 없습니다.");
        }

        signupService.sendPasswordResetCode(member);
        log.info("관리자 비밀번호 재설정 안내 발송 - ID: {}, 학번: {}", id, member.getLoginId());
    }

    /**
     * 관리자 권한 비밀번호 재설정 (임시 비밀번호 또는 초기 비활성화 상태 복구)
     * 여기서는 비밀번호를 TEMP 상태로 다시 초기화하여 계정을 비활성(isActivated = false) 상태로 만들고,
     * 사용자가 이메일 인증을 통해 다시 가입 프로세스를 밟도록 구성합니다. (완벽한 계정 리셋)
     */
    @Transactional
    public void resetMemberRegistration(Long id) {
        Member member = findMember(id);
        if (member.getRole() == MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("SUPER_ADMIN 계정의 비밀번호는 관리자 도구로 초기화할 수 없습니다.");
        }

        member.setPassword(passwordEncoder.encode("TEMP_" + member.getLoginId() + "_" + System.currentTimeMillis()));
        member.setEmail(null);
        member.setActivated(false); // 가입 대기 상태로 리셋
        member.setAuthVersion(member.getAuthVersion() + 1);
        member.setFcmToken(null);
        // 💡 진행 중이던 인증과 재발급 쿨다운까지 함께 지웁니다. 초기화 직후에는 바로 재인증할 수 있어야 합니다.
        verificationService.clear(member.getLoginId());
        memberRepository.save(member);
        log.info("관리자 회원 계정 재등록 초기화 완료 - ID: {}, 학번: {} (가입 대기 상태로 전환)", id, member.getLoginId());
    }

    /**
     * 관리자 회원 차단 처리 (isSuspended = true)
     */
    @Transactional
    public void suspendMember(Long id) {
        Member member = findMember(id);
        if (member.getRole() == MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("SUPER_ADMIN 계정은 차단할 수 없습니다.");
        }
        member.setSuspended(true);
        memberRepository.save(member);
        log.info("관리자 회원 차단 완료 - ID: {}, 학번: {}", id, member.getLoginId());
    }

    /**
     * 관리자 회원 차단 해제 처리 (isSuspended = false)
     */
    @Transactional
    public void unsuspendMember(Long id) {
        Member member = findMember(id);
        member.setSuspended(false);
        memberRepository.save(member);
        log.info("관리자 회원 차단 해제 완료 - ID: {}, 학번: {}", id, member.getLoginId());
    }

    private Member findMember(Long id) {
        return memberRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));
    }
}
