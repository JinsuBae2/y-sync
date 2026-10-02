package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.Member;
import com.ync.ysync.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 💡 회원의 기본 조회와 로그인, 그리고 본인이 바꾸는 개인 설정을 담당합니다.
 *
 * 이 클래스는 원래 925줄이었고 가입·인증·명단 업로드·관리자 조작까지 전부 들고 있었습니다.
 * 2026-09-21에 네 갈래로 나눴습니다.
 *
 * <ul>
 *   <li>{@link MemberVerificationService} — 인증번호·가입 증표의 발급과 검증 (인메모리 상태)</li>
 *   <li>{@link MemberSignupService} — 가입과 비밀번호 재설정 흐름</li>
 *   <li>{@link MemberSpreadsheetImportService} — 학생 명단 CSV·Excel 일괄 등록</li>
 *   <li>{@link MemberAdminService} — 관리자 전용 회원 관리</li>
 * </ul>
 *
 * 나누는 기준은 줄 수가 아니라 <b>누가 부르는가</b>였습니다. 컨트롤러 셋이 각각 필요한 것만
 * 주입받게 되어, 관리자 컨트롤러가 가입을, 프로필 컨트롤러가 차단을 부를 수 있던 상태가 사라집니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MemberService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;

    /**
     * 로그인 로직
     */
    @Transactional(readOnly = true)
    public Member login(String loginId, String password) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException("아이디 또는 비밀번호가 맞지 않습니다."));

        // 가입 완료 여부 검증 (isActivated = false 인 계정은 로그인 차단)
        if (!member.isActivated()) {
            throw new IllegalArgumentException("회원가입이 완료되지 않은 계정입니다. 이메일 인증 가입을 완료해 주세요.");
        }

        if (!passwordEncoder.matches(password, member.getPassword())) {
            throw new IllegalArgumentException("아이디 또는 비밀번호가 맞지 않습니다.");
        }

        return member;
    }

    /**
     * 소셜 로그인 (비활성화 및 deprecate 경고용)
     */
    @Transactional(readOnly = true)
    public Member socialLogin(String socialId, AuthProvider provider) {
        throw new UnsupportedOperationException("소셜 로그인 기능은 비활성화되었습니다. 학번 기반 로그인을 이용해 주세요.");
    }

    /**
     * 소셜 회원가입 (비활성화 및 deprecate 경고용)
     */
    @Transactional
    public Member socialSignup(String loginId, String name, String socialId, AuthProvider provider, String password) {
        throw new UnsupportedOperationException("소셜 회원가입 기능은 비활성화되었습니다. 학번 기반 로그인을 이용해 주세요.");
    }

    @Transactional(readOnly = true)
    public Member findById(Long id) {
        return memberRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));
    }

    // 💡 FCM 토큰 업데이트
    @Transactional
    public void updateFcmToken(Long memberId, String fcmToken) {
        Member member = findById(memberId);
        member.setFcmToken(fcmToken);
    }

    // 💡 알림 설정 업데이트
    @Transactional
    public void updateNotificationSettings(Long memberId, boolean noticeEnabled, boolean commentEnabled) {
        Member member = findById(memberId);
        member.setNoticeEnabled(noticeEnabled);
        member.setCommentEnabled(commentEnabled);
    }
}
