package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.NoticeGradePreference;
import com.ync.ysync.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 💡 가입과 비밀번호 재설정 흐름을 담당합니다.
 *
 * 인증번호·증표의 발급과 검증은 {@link MemberVerificationService}가 맡고, 여기서는
 * "누구에게 보낼 수 있는가", "무엇을 확인한 뒤 계정을 활성화하는가" 같은 회원 쪽 판단만 합니다.
 * 두 관심사를 한 클래스에 두면 인메모리 맵의 원자성 경계가 회원 조회 로직과 섞여 읽기 어려워집니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MemberSignupService {

    // 💡 '명단에 없음'과 '이름 불일치'를 구분하지 않기 위한 공통 메시지입니다.
    //    두 경우를 다르게 답하면 어떤 학번이 명단에 있는지 조회할 수 있게 됩니다.
    private static final String SIGNUP_LOOKUP_FAILURE_MESSAGE =
            "학번과 이름을 확인해 주세요. 등록되지 않은 경우 학과 사무실에 문의하세요.";

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;
    private final MemberVerificationService verificationService;

    /**
     * 회원가입 전 학번과 이름 일치 여부 1차 검증
     */
    @Transactional(readOnly = true)
    public void verifyStudentForSignup(String loginId, String name) {
        // 💡 응답으로 '명단에 있지만 아직 가입하지 않은 학번'을 골라낼 수 없어야 합니다.
        //    그 조합이 곧 타인 명의 가입의 표적이며, 학번을 순서대로 넣어보면 표적 명단이 만들어집니다.
        //    따라서 '등록되지 않은 학번'과 '이름 불일치'를 같은 응답으로 돌려줍니다.
        //    이미 가입된 경우는 구분해 알려줍니다. 정상 사용자에게 로그인으로 안내해야 하고,
        //    공격자가 찾는 것은 '미가입' 상태라 이 정보만으로는 표적을 좁힐 수 없습니다.
        //    비밀번호 재설정(`requestPasswordReset`)이 이미 같은 기준을 따르고 있습니다.
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException(SIGNUP_LOOKUP_FAILURE_MESSAGE));

        if (member.isActivated()) {
            throw new IllegalArgumentException("이미 가입이 완료된 학번입니다. 로그인해 주세요.");
        }

        if (!member.getName().equals(name)) {
            throw new IllegalArgumentException(SIGNUP_LOOKUP_FAILURE_MESSAGE);
        }
    }

    /**
     * 회원가입을 위한 인증번호 전송
     */
    public void sendVerificationEmail(String loginId, String name, String email) {
        // 1. 사전 등록 여부 및 이름 일치 검증 (1차 검증 재호출로 보안 보장)
        verifyStudentForSignup(loginId, name);

        // 이메일 형식 검증 (도메인이 ync.ac.kr 인지 점검)
        String toEmail = normalizeSchoolEmail(email);
        memberRepository.findByEmail(toEmail)
                .filter(existing -> !existing.getLoginId().equals(loginId))
                .ifPresent(existing -> {
                    throw new IllegalArgumentException("이미 다른 계정에 등록된 이메일입니다.");
                });

        // 2. 6자리 인증번호 발급 (재발급 간격 제한 포함)
        String code = verificationService.issueCode(
                loginId, toEmail, MemberVerificationService.Purpose.SIGNUP);

        // 3. 이메일 발송
        emailService.sendVerificationCode(toEmail, code);
    }

    /**
     * 인증번호 검증. 성공 시 가입 요청에 제시할 증표를 반환합니다.
     */
    public String verifySignupCode(String loginId, String code) {
        String verifiedEmail = verificationService.consumeCode(
                loginId, code, MemberVerificationService.Purpose.SIGNUP);
        return verificationService.issueSignupGrant(loginId, verifiedEmail);
    }

    /**
     * 최종 회원가입 및 계정 활성화
     */
    @Transactional
    public Member signup(String loginId, String password, String name, String verificationGrant) {
        return signup(loginId, password, name, verificationGrant, null, null);
    }

    /**
     * 최종 회원가입 및 계정 활성화 (공지 알림 수신 학년 선택 포함)
     *
     * 💡 학년 선택값과 확인 학년도는 가입 트랜잭션 안에서 함께 저장합니다. 가입이 실패하면 함께 롤백되어
     *    확인 완료 상태만 남는 일이 없습니다. 확인 학년도는 클라이언트가 지정하지 않고 서버가 계산한 값을 받습니다.
     *    이전 버전 클라이언트 호환을 위해 선택값이 없으면 미설정으로 둡니다.
     */
    @Transactional
    public Member signup(String loginId, String password, String name, String verificationGrant,
                         NoticeGradePreference noticeGradePreference, Integer academicYear) {
        // 💡 비밀번호 정책은 인증 상태를 확인하기 전에 검사합니다. 정책 위반 같은 단순 입력 오류로
        //    이메일 인증 결과가 소모되지 않아야 사용자가 같은 인증으로 다시 시도할 수 있습니다.
        //    기존에는 이 검사가 비밀번호 재설정에만 있어 회원가입에서는 한 글자 비밀번호도 허용됐습니다.
        validatePassword(password);

        // 1. 인증 증표 검증 및 소비
        // 💡 이전 구현은 통과 기록을 학번만으로 조회해, 다른 사람이 인증을 마친 뒤 그 유효 시간 안에
        //    학번과 이름만 아는 제3자가 가입을 완료할 수 있었습니다. 이제 인증한 주체만 가진 증표를
        //    요구하며, 소비는 원자적이라 같은 증표로 두 번 가입할 수 없습니다.
        String verifiedEmail = verificationService.consumeSignupGrant(loginId, verificationGrant);

        // 2. 사전 등록 계정 조회
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException("등록되지 않은 학번입니다. 학과 사무실에 문의하세요."));

        if (member.isActivated()) {
            throw new IllegalArgumentException("이미 활성화된 회원입니다.");
        }

        // 3. 이름 일치 확인
        if (!member.getName().equals(name)) {
            throw new IllegalArgumentException("사전 등록된 이름과 입력한 이름이 일치하지 않습니다.");
        }

        // 4. 패스워드 설정 및 계정 활성화
        member.setPassword(passwordEncoder.encode(password));
        member.setEmail(verifiedEmail);
        member.setActivated(true);

        if (noticeGradePreference != null) {
            member.setNoticeGradePreference(noticeGradePreference);
            member.setGradeConfirmedYear(academicYear);
        }

        // 💡 학교 메일 주소는 학번에서 유도할 수 없으므로(사용자 정의 ID) 가입 주체를 서버가 사전에 검증할 수 없습니다.
        //    대신 어떤 메일 계정이 어떤 학번으로 가입했는지를 남겨, 도용 신고 시 가해자를 특정할 수 있게 합니다.
        log.info("회원 가입 완료 - 학번: {}, 이름: {}, 인증 메일: {}", loginId, name, verifiedEmail);

        return memberRepository.save(member);
    }

    public void requestPasswordReset(String loginId, String name) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException("등록된 계정 정보를 확인할 수 없습니다."));

        if (!member.isActivated() || !member.getName().equals(name)) {
            throw new IllegalArgumentException("등록된 계정 정보를 확인할 수 없습니다.");
        }

        sendPasswordResetCode(member);
    }

    /**
     * 💡 회원의 등록 이메일로 재설정 인증번호를 보냅니다.
     *
     * 관리자 도구({@code MemberAdminService})도 이 경로를 씁니다. 관리자 쪽의 추가 제약
     * (SUPER_ADMIN 제외, 가입 대기 계정 제외)은 호출하는 쪽에서 판단합니다.
     */
    public void sendPasswordResetCode(Member member) {
        if (member.getEmail() == null || member.getEmail().isBlank()) {
            throw new IllegalArgumentException("등록된 이메일이 없습니다. 계정 재등록 초기화를 이용해 주세요.");
        }

        String code = verificationService.issueCode(
                member.getLoginId(), member.getEmail(), MemberVerificationService.Purpose.PASSWORD_RESET);
        emailService.sendPasswordResetCode(member.getEmail(), code);
    }

    @Transactional
    public void confirmPasswordReset(String loginId, String code, String newPassword) {
        validatePassword(newPassword);

        // 💡 인증번호 검증과 비밀번호 변경이 같은 요청에 있으므로 중간 저장소가 필요 없습니다.
        //    소비된 challenge가 인증된 이메일을 들고 있어 회원 이메일과 바로 대조합니다.
        String verifiedEmail = verificationService.consumeCode(
                loginId, code, MemberVerificationService.Purpose.PASSWORD_RESET);

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException("등록된 계정을 찾을 수 없습니다."));
        if (!verifiedEmail.equals(member.getEmail())) {
            throw new IllegalArgumentException("인증 정보가 일치하지 않습니다. 다시 시도해 주세요.");
        }

        member.setPassword(passwordEncoder.encode(newPassword));
        member.setAuthVersion(member.getAuthVersion() + 1);
        member.setFcmToken(null);
        memberRepository.save(member);
        log.info("비밀번호 재설정 완료 - 학번: {}", loginId);
    }

    private String normalizeSchoolEmail(String email) {
        String normalized = email.trim().toLowerCase();
        if (!normalized.contains("@")) {
            normalized += "@ync.ac.kr";
        }
        if (!normalized.endsWith("@ync.ac.kr")) {
            throw new IllegalArgumentException("영남이공대학교 이메일(@ync.ac.kr)만 사용 가능합니다.");
        }
        return normalized;
    }

    private void validatePassword(String password) {
        if (password == null || password.length() < 8 || password.length() > 64
                || !password.matches(".*[A-Za-z].*") || !password.matches(".*\\d.*")
                || !password.matches(".*[^A-Za-z0-9].*")) {
            throw new IllegalArgumentException("비밀번호는 8~64자의 영문, 숫자, 특수문자를 포함해야 합니다.");
        }
    }
}
