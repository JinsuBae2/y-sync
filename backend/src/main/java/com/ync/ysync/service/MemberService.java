package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.NoticeGradePreference;
import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.repository.MemberRepository;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.FormulaEvaluator;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicReference;

@Slf4j
@Service
@RequiredArgsConstructor
public class MemberService {

    private static final Set<String> CSV_LOGIN_ID_HEADERS = Set.of(
            "학번", "학생번호", "학생학번", "studentid", "loginid");
    private static final Set<String> CSV_NAME_HEADERS = Set.of(
            "이름", "성명", "학생명", "name", "studentname");
    private static final Set<String> CSV_ROLE_HEADERS = Set.of(
            "역할", "권한", "role");

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    // 💡 인증번호는 한 번 발급된 뒤 5분간 고정되므로, 시도 횟수를 제한하지 않으면 6자리(10^6)를
    //    무차별 대입할 수 있습니다. 아래 상수로 challenge당 시도 횟수와 재발급 간격을 제한합니다.
    private static final int MAX_VERIFICATION_ATTEMPTS = 5;
    private static final int VERIFICATION_TTL_MINUTES = 5;
    private static final int RESEND_COOLDOWN_SECONDS = 60;
    private static final int SIGNUP_GRANT_TTL_MINUTES = 10;

    // 💡 인증 코드 및 가입 허가 정보를 담을 인메모리 스토리지
    private final ConcurrentHashMap<String, VerificationInfo> verificationCodes = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, VerifiedInfo> verifiedStudents = new ConcurrentHashMap<>();
    // 💡 재발급 가능 시각. challenge가 시도 초과로 삭제돼도 남아야 "5회 실패 → 즉시 재발급 → 5회 더"
    //    방식의 우회를 막을 수 있으므로 별도로 보관합니다. 키가 학번이라 크기는 회원 수로 제한됩니다.
    private final ConcurrentHashMap<String, LocalDateTime> verificationResendAvailableAt = new ConcurrentHashMap<>();
    private final SecureRandom secureRandom = new SecureRandom();

    private enum VerificationPurpose {
        SIGNUP,
        PASSWORD_RESET
    }

    /**
     * 💡 `verifyCode`의 판정 결과입니다. `ConcurrentHashMap.compute`의 remapping function 안에서
     * 예외를 던지면 매핑 갱신이 취소되어 시도 횟수 증가가 사라지므로, 판정만 이 값으로 돌려받고
     * 예외는 `compute` 종료 후 바깥에서 던집니다.
     */
    private enum VerifyOutcome {
        NOT_FOUND,
        EXPIRED,
        PURPOSE_MISMATCH,
        CODE_MISMATCH,
        ATTEMPTS_EXHAUSTED,
        SUCCESS
    }

    @Getter
    @AllArgsConstructor
    private static class VerificationInfo {
        private final String code;
        private final LocalDateTime expiredAt;
        private final String email;
        private final VerificationPurpose purpose;
        private final int attemptCount;

        /** 💡 불변으로 유지합니다. 제자리 변경은 맵 수준 원자성 밖에서 공유 상태를 건드리게 됩니다. */
        private VerificationInfo withFailedAttempt() {
            return new VerificationInfo(code, expiredAt, email, purpose, attemptCount + 1);
        }
    }

    @Getter
    @AllArgsConstructor
    private static class VerifiedInfo {
        private final LocalDateTime expiredAt;
        private final String email;
        private final VerificationPurpose purpose;
        // 💡 인증을 통과한 주체에게만 발급하는 증표입니다. 이 값이 없으면 통과 기록이 학번만으로
        //    식별되어, 학번과 이름만 아는 제3자가 남의 인증 결과로 가입을 완료할 수 있습니다.
        private final String grant;
    }

    /** 💡 가입 증표 판정 결과입니다. {@code compute} 안에서 예외를 던지지 않기 위해 분리합니다. */
    private enum GrantOutcome {
        NOT_FOUND,
        EXPIRED,
        PURPOSE_MISMATCH,
        GRANT_MISMATCH,
        SUCCESS
    }

    /**
     * 회원가입 전 학번과 이름 일치 여부 1차 검증
     */
    @Transactional(readOnly = true)
    public void verifyStudentForSignup(String loginId, String name) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException("등록되지 않은 학번입니다. 학과 사무실에 문의하세요."));

        if (member.isActivated()) {
            throw new IllegalArgumentException("이미 회원가입이 완료된 학번입니다.");
        }

        if (!member.getName().equals(name)) {
            throw new IllegalArgumentException("학번과 이름이 일치하지 않습니다.");
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
        String code = issueVerificationCode(loginId, toEmail, VerificationPurpose.SIGNUP);

        // 3. 이메일 발송
        emailService.sendVerificationCode(toEmail, code);
    }

    /**
     * 💡 인증번호를 발급하고 저장합니다.
     *
     * 재발급은 {@link #RESEND_COOLDOWN_SECONDS}초 간격으로 제한합니다. 이 제한이 없으면
     * "시도 횟수를 소진한 뒤 즉시 재발급"을 반복해 시도 제한을 그대로 우회할 수 있고,
     * 메일 발송 할당량도 무제한으로 소모됩니다. 새 코드를 넣으면 기존 challenge는 폐기됩니다.
     */
    private String issueVerificationCode(String loginId, String toEmail, VerificationPurpose purpose) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime availableAt = verificationResendAvailableAt.get(loginId);
        if (availableAt != null && now.isBefore(availableAt)) {
            throw new IllegalArgumentException("인증번호는 잠시 후에 다시 요청할 수 있습니다.");
        }

        String code = generateVerificationCode();
        verificationCodes.put(loginId, new VerificationInfo(
                code, now.plusMinutes(VERIFICATION_TTL_MINUTES), toEmail, purpose, 0));
        verificationResendAvailableAt.put(loginId, now.plusSeconds(RESEND_COOLDOWN_SECONDS));
        return code;
    }

    /**
     * 인증번호 검증
     */
    public String verifySignupCode(String loginId, String code) {
        VerificationInfo consumed = verifyCode(loginId, code, VerificationPurpose.SIGNUP);

        // 💡 가입은 인증과 최종 제출이 분리된 흐름이라 통과 기록을 남겨야 합니다. 이때 학번만 남기면
        //    누가 인증했는지 알 수 없으므로, 추측할 수 없는 증표를 함께 발급해 인증한 주체에게만 돌려줍니다.
        //    가입 요청은 이 증표를 제시해야 하며(`signup`), 증표는 한 번 쓰면 즉시 폐기됩니다.
        String grant = issueSignupGrant();
        verifiedStudents.put(loginId, new VerifiedInfo(
                LocalDateTime.now().plusMinutes(SIGNUP_GRANT_TTL_MINUTES),
                consumed.getEmail(), VerificationPurpose.SIGNUP, grant));
        purgeExpiredSignupGrants();
        return grant;
    }

    /** 💡 추측 불가능한 가입 증표를 만듭니다. 256비트 난수를 URL 안전 형식으로 인코딩합니다. */
    private String issueSignupGrant() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /**
     * 💡 만료된 통과 기록을 정리합니다.
     *
     * 이 맵은 소비되거나 만료로 걸러질 때만 비워지므로, 인증만 하고 가입하지 않는 요청이 쌓이면
     * 항목이 남습니다. 키가 학번이라 상한은 회원 수지만, 불필요한 증표를 유효 시간 이상 들고 있지
     * 않도록 발급 시점에 함께 청소합니다.
     */
    private void purgeExpiredSignupGrants() {
        LocalDateTime now = LocalDateTime.now();
        verifiedStudents.values().removeIf(info -> info.getExpiredAt().isBefore(now));
    }

    /**
     * 💡 제시된 증표를 원자적으로 검증하고 소비합니다.
     *
     * 같은 증표로 거의 동시에 들어온 요청이 둘 다 통과하지 않도록, 조회·검증·삭제를
     * {@code compute} 한 번으로 묶어 최대 한 번만 성공하게 합니다.
     */
    private VerifiedInfo consumeSignupGrant(String loginId, String grant) {
        AtomicReference<GrantOutcome> outcome = new AtomicReference<>();
        AtomicReference<VerifiedInfo> consumed = new AtomicReference<>();

        verifiedStudents.compute(loginId, (key, info) -> {
            if (info == null) {
                outcome.set(GrantOutcome.NOT_FOUND);
                return null;
            }
            if (info.getExpiredAt().isBefore(LocalDateTime.now())) {
                outcome.set(GrantOutcome.EXPIRED);
                return null;
            }
            if (info.getPurpose() != VerificationPurpose.SIGNUP) {
                outcome.set(GrantOutcome.PURPOSE_MISMATCH);
                return info;
            }
            // 💡 틀린 증표는 통과 기록을 지우지 않습니다. 제3자가 아무 값이나 보내서
            //    정상 사용자의 인증 결과를 날려버리는 것을 막기 위함입니다.
            if (!constantTimeEquals(info.getGrant(), grant)) {
                outcome.set(GrantOutcome.GRANT_MISMATCH);
                return info;
            }
            outcome.set(GrantOutcome.SUCCESS);
            consumed.set(info);
            return null; // 소비 후 폐기. 재사용을 막습니다.
        });

        switch (outcome.get()) {
            case NOT_FOUND, EXPIRED ->
                    throw new IllegalArgumentException("이메일 인증이 완료되지 않았거나 인증 시간이 초과되었습니다.");
            case PURPOSE_MISMATCH, GRANT_MISMATCH ->
                    throw new IllegalArgumentException("가입 인증 정보가 올바르지 않습니다. 인증을 다시 진행해 주세요.");
            case SUCCESS -> { /* 계속 진행 */ }
        }
        return consumed.get();
    }

    /** 💡 증표 비교는 길이·내용 모두 시간 정보를 흘리지 않도록 상수 시간으로 수행합니다. */
    private boolean constantTimeEquals(String expected, String actual) {
        if (expected == null || actual == null) {
            return false;
        }
        return java.security.MessageDigest.isEqual(
                expected.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                actual.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    /**
     * 💡 인증번호를 원자적으로 검증하고 소비합니다. 성공 시 소비된 challenge를 반환합니다.
     *
     * 조회·검증·시도 횟수 증가·삭제를 {@code compute} 한 번으로 묶습니다. 이전 구현은
     * `get → 검증 → remove` 구조라 같은 코드로 거의 동시에 들어온 두 요청이 모두 통과할 수
     * 있었고, 비밀번호 재설정에서는 서로 다른 비밀번호가 경쟁할 수 있었습니다.
     *
     * 반환값을 쓰는 이유: 호출자가 인증된 이메일을 중간 저장소를 거치지 않고 바로 받을 수 있어,
     * 비밀번호 재설정이 `verifiedStudents`에 의존하지 않게 됩니다.
     */
    private VerificationInfo verifyCode(String loginId, String code, VerificationPurpose purpose) {
        AtomicReference<VerifyOutcome> outcome = new AtomicReference<>();
        AtomicReference<VerificationInfo> consumed = new AtomicReference<>();

        verificationCodes.compute(loginId, (key, info) -> {
            if (info == null) {
                outcome.set(VerifyOutcome.NOT_FOUND);
                return null;
            }
            if (info.getExpiredAt().isBefore(LocalDateTime.now())) {
                outcome.set(VerifyOutcome.EXPIRED);
                return null;
            }
            // 목적 불일치는 사용자의 추측이 아니라 호출 오류이므로 시도 횟수를 소모하지 않습니다.
            if (info.getPurpose() != purpose) {
                outcome.set(VerifyOutcome.PURPOSE_MISMATCH);
                return info;
            }
            if (!info.getCode().equals(code)) {
                VerificationInfo attempted = info.withFailedAttempt();
                if (attempted.getAttemptCount() >= MAX_VERIFICATION_ATTEMPTS) {
                    outcome.set(VerifyOutcome.ATTEMPTS_EXHAUSTED);
                    return null; // challenge 폐기. 계정은 잠그지 않습니다.
                }
                outcome.set(VerifyOutcome.CODE_MISMATCH);
                return attempted;
            }
            outcome.set(VerifyOutcome.SUCCESS);
            consumed.set(info);
            return null; // 성공 시 소비하여 재사용을 막습니다.
        });

        switch (outcome.get()) {
            case NOT_FOUND -> throw new IllegalArgumentException("인증 요청 기록이 없거나 만료되었습니다.");
            case EXPIRED -> throw new IllegalArgumentException("인증 시간이 만료되었습니다. 다시 시도해주세요.");
            case PURPOSE_MISMATCH -> throw new IllegalArgumentException("인증 목적이 올바르지 않습니다. 인증번호를 다시 요청해 주세요.");
            case CODE_MISMATCH -> throw new IllegalArgumentException("인증 번호가 일치하지 않습니다.");
            case ATTEMPTS_EXHAUSTED -> throw new IllegalArgumentException("인증 시도 횟수를 초과했습니다. 인증번호를 다시 요청해 주세요.");
            case SUCCESS -> log.info("인증 성공 - 학번: {}, 목적: {}", loginId, purpose);
        }
        return consumed.get();
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
        VerifiedInfo verifiedInfo = consumeSignupGrant(loginId, verificationGrant);

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
        member.setEmail(verifiedInfo.getEmail());
        member.setActivated(true);

        if (noticeGradePreference != null) {
            member.setNoticeGradePreference(noticeGradePreference);
            member.setGradeConfirmedYear(academicYear);
        }

        // 💡 학교 메일 주소는 학번에서 유도할 수 없으므로(사용자 정의 ID) 가입 주체를 서버가 사전에 검증할 수 없습니다.
        //    대신 어떤 메일 계정이 어떤 학번으로 가입했는지를 남겨, 도용 신고 시 가해자를 특정할 수 있게 합니다.
        log.info("회원 가입 완료 - 학번: {}, 이름: {}, 인증 메일: {}", loginId, name, verifiedInfo.getEmail());

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

    public void requestPasswordResetByAdmin(Long id) {
        Member member = findById(id);
        if (member.getRole() == MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("SUPER_ADMIN 계정은 관리자 도구로 재설정할 수 없습니다.");
        }
        if (!member.isActivated()) {
            throw new IllegalArgumentException("가입 대기 계정은 비밀번호를 재설정할 수 없습니다.");
        }

        sendPasswordResetCode(member);
        log.info("관리자 비밀번호 재설정 안내 발송 - ID: {}, 학번: {}", id, member.getLoginId());
    }

    private void sendPasswordResetCode(Member member) {
        if (member.getEmail() == null || member.getEmail().isBlank()) {
            throw new IllegalArgumentException("등록된 이메일이 없습니다. 계정 재등록 초기화를 이용해 주세요.");
        }

        String code = issueVerificationCode(
                member.getLoginId(), member.getEmail(), VerificationPurpose.PASSWORD_RESET);
        emailService.sendPasswordResetCode(member.getEmail(), code);
    }

    @Transactional
    public void confirmPasswordReset(String loginId, String code, String newPassword) {
        validatePassword(newPassword);

        // 💡 인증번호 검증과 비밀번호 변경이 같은 요청에 있으므로 중간 저장소가 필요 없습니다.
        //    소비된 challenge가 인증된 이메일을 들고 있어 회원 이메일과 바로 대조합니다.
        VerificationInfo consumed = verifyCode(loginId, code, VerificationPurpose.PASSWORD_RESET);

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException("등록된 계정을 찾을 수 없습니다."));
        if (!consumed.getEmail().equals(member.getEmail())) {
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

    private String generateVerificationCode() {
        return String.format("%06d", secureRandom.nextInt(1_000_000));
    }

    private void validatePassword(String password) {
        if (password == null || password.length() < 8 || password.length() > 64
                || !password.matches(".*[A-Za-z].*") || !password.matches(".*\\d.*")
                || !password.matches(".*[^A-Za-z0-9].*")) {
            throw new IllegalArgumentException("비밀번호는 8~64자의 영문, 숫자, 특수문자를 포함해야 합니다.");
        }
    }

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

    // ==========================================
    // 관리자(Admin) 전용 회원 관리 비즈니스 로직
    // ==========================================

    /**
     * 전체 회원 목록 페이징 및 이름/학번 검색 조회
     */
    @Transactional(readOnly = true)
    public Page<Member> getMembers(Pageable pageable, String search) {
        if (search == null || search.trim().isEmpty()) {
            return memberRepository.findAll(pageable);
        }
        return memberRepository.findByLoginIdContainingOrNameContaining(search, search, pageable);
    }

    /**
     * 관리자 단건 사전 등록
     */
    @Transactional
    public Member createMemberByAdmin(String loginId, String name, MemberRole role, MemberRole actorRole) {
        MemberRole requestedRole = role != null ? role : MemberRole.USER;
        validateRoleAssignment(actorRole, requestedRole);
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
     * CSV 데이터 일괄 업로드 등록
     */
    @Transactional
    public CsvImportResult createMembersBySpreadsheet(
            InputStream stream, String filename, MemberRole actorRole) {
        String normalizedFilename = filename == null ? "" : filename.trim().toLowerCase();
        if (normalizedFilename.endsWith(".csv")) {
            return createMembersByCsv(stream, actorRole);
        }
        if (normalizedFilename.endsWith(".xlsx") || normalizedFilename.endsWith(".xls")) {
            return createMembersByCsv(excelToCsv(stream), actorRole);
        }
        throw new IllegalArgumentException("CSV 또는 Excel(.xlsx, .xls) 파일만 업로드할 수 있습니다.");
    }

    private InputStream excelToCsv(InputStream stream) {
        try (Workbook workbook = WorkbookFactory.create(stream)) {
            if (workbook.getNumberOfSheets() == 0) {
                throw new IllegalArgumentException("Excel 파일에 시트가 없습니다.");
            }
            Sheet sheet = workbook.getSheetAt(0);
            DataFormatter formatter = new DataFormatter();
            FormulaEvaluator evaluator = workbook.getCreationHelper().createFormulaEvaluator();
            StringBuilder csv = new StringBuilder();
            for (Row row : sheet) {
                int lastCell = Math.max(row.getLastCellNum(), 0);
                for (int column = 0; column < lastCell; column++) {
                    if (column > 0) {
                        csv.append(',');
                    }
                    var cell = row.getCell(column);
                    String value = cell == null ? "" : formatter.formatCellValue(cell, evaluator)
                            .replace('\r', ' ').replace('\n', ' ');
                    csv.append(escapeCsvValue(value));
                }
                csv.append('\n');
            }
            return new ByteArrayInputStream(csv.toString().getBytes(StandardCharsets.UTF_8));
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalArgumentException("Excel 파일을 읽을 수 없습니다: " + e.getMessage(), e);
        }
    }

    private String escapeCsvValue(String value) {
        if (value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }

    @Transactional
    public CsvImportResult createMembersByCsv(InputStream csvStream, MemberRole actorRole) {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(csvStream, StandardCharsets.UTF_8))) {
            String line;
            boolean isFirstLine = true;
            int rowNumber = 0;
            int totalCount = 0;
            int duplicateCount = 0;
            int loginIdColumn = 0;
            int nameColumn = 1;
            int roleColumn = 2;
            List<CsvMemberRow> validRows = new ArrayList<>();
            List<CsvImportError> errors = new ArrayList<>();
            Set<String> loginIdsInFile = new HashSet<>();

            while ((line = reader.readLine()) != null) {
                rowNumber++;
                if (line.trim().isEmpty())
                    continue;

                // UTF-8 BOM 제거
                if (isFirstLine && line.startsWith("\uFEFF")) {
                    line = line.substring(1);
                }

                List<String> parts = parseCsvLine(line);

                // 헤더가 있으면 필요한 열만 이름으로 찾아 사용하고 나머지는 무시한다.
                if (isFirstLine && isCsvHeaderRow(parts)) {
                    loginIdColumn = findHeaderIndex(parts, CSV_LOGIN_ID_HEADERS);
                    nameColumn = findHeaderIndex(parts, CSV_NAME_HEADERS);
                    roleColumn = findHeaderIndex(parts, CSV_ROLE_HEADERS);
                    isFirstLine = false;
                    if (loginIdColumn < 0 || nameColumn < 0) {
                        throw new IllegalArgumentException("CSV 헤더에서 학번과 이름 열을 찾을 수 없습니다.");
                    }
                    continue;
                }
                isFirstLine = false;
                totalCount++;

                String loginId = csvValue(parts, loginIdColumn);
                String name = csvValue(parts, nameColumn);
                if (loginId.isEmpty() && name.isEmpty()) {
                    errors.add(new CsvImportError(rowNumber, "", "학번과 이름이 비어 있습니다."));
                    continue;
                }

                // 학번은 숫자만 포함되어야 함
                if (!loginId.matches("^\\d+$")) {
                    log.warn("CSV 파싱 - 올바르지 않은 학번 형식 건너뜀: {}", loginId);
                    errors.add(new CsvImportError(rowNumber, loginId, "학번은 숫자만 입력할 수 있습니다."));
                    continue;
                }
                if (name.isEmpty()) {
                    errors.add(new CsvImportError(rowNumber, loginId, "이름이 비어 있습니다."));
                    continue;
                }
                MemberRole role = MemberRole.USER;
                String roleValue = csvValue(parts, roleColumn);
                if (!roleValue.isEmpty()) {
                    try {
                        role = MemberRole.valueOf(roleValue.toUpperCase());
                    } catch (IllegalArgumentException e) {
                        errors.add(new CsvImportError(rowNumber, loginId, "알 수 없는 권한입니다: " + roleValue));
                        continue;
                    }
                }
                try {
                    validateRoleAssignment(actorRole, role);
                } catch (IllegalArgumentException e) {
                    errors.add(new CsvImportError(rowNumber, loginId, e.getMessage()));
                    continue;
                }
                if (!loginIdsInFile.add(loginId)) {
                    duplicateCount++;
                    continue;
                }
                validRows.add(new CsvMemberRow(loginId, name, role));
            }

            Set<String> existingLoginIds = new HashSet<>();
            if (!validRows.isEmpty()) {
                memberRepository.findAllByLoginIdIn(validRows.stream().map(CsvMemberRow::loginId).toList())
                        .stream().map(Member::getLoginId).forEach(existingLoginIds::add);
            }

            List<Member> membersToSave = new ArrayList<>();
            for (CsvMemberRow row : validRows) {
                if (existingLoginIds.contains(row.loginId())) {
                    duplicateCount++;
                    continue;
                }
                membersToSave.add(Member.builder()
                        .loginId(row.loginId())
                        .password(passwordEncoder.encode("TEMP_" + row.loginId() + "_" + System.currentTimeMillis()))
                        .name(row.name())
                        .role(row.role())
                        .isActivated(false)
                        .provider(AuthProvider.LOCAL)
                        .authType(AuthType.PASSWORD)
                        .build());
            }
            memberRepository.saveAll(membersToSave);

            CsvImportResult result = new CsvImportResult(totalCount, membersToSave.size(), duplicateCount, errors);
            log.info("학생 명단 일괄 사전등록 완료 - 신규 {}명, 중복 {}명, 오류 {}건",
                    result.createdCount(), result.duplicateCount(), result.errorCount());
            return result;
        } catch (Exception e) {
            throw new RuntimeException("학생 명단 파일 파싱 및 등록 중 오류가 발생했습니다: " + e.getMessage(), e);
        }
    }

    private record CsvMemberRow(String loginId, String name, MemberRole role) {
    }

    private boolean isCsvHeaderRow(List<String> values) {
        return values.stream()
                .map(this::normalizeCsvHeader)
                .anyMatch(header -> CSV_LOGIN_ID_HEADERS.contains(header)
                        || CSV_NAME_HEADERS.contains(header)
                        || CSV_ROLE_HEADERS.contains(header));
    }

    private int findHeaderIndex(List<String> values, Set<String> aliases) {
        for (int index = 0; index < values.size(); index++) {
            if (aliases.contains(normalizeCsvHeader(values.get(index)))) {
                return index;
            }
        }
        return -1;
    }

    private String normalizeCsvHeader(String value) {
        return value.trim().toLowerCase().replaceAll(" ", "").replaceAll("_", "").replaceAll("-", "");
    }

    private String csvValue(List<String> values, int index) {
        return index >= 0 && index < values.size() ? values.get(index).trim() : "";
    }

    private List<String> parseCsvLine(String line) {
        List<String> values = new ArrayList<>();
        StringBuilder value = new StringBuilder();
        boolean quoted = false;
        for (int index = 0; index < line.length(); index++) {
            char current = line.charAt(index);
            if (current == '"') {
                if (quoted && index + 1 < line.length() && line.charAt(index + 1) == '"') {
                    value.append('"');
                    index++;
                } else {
                    quoted = !quoted;
                }
            } else if (current == ',' && !quoted) {
                values.add(value.toString());
                value.setLength(0);
            } else {
                value.append(current);
            }
        }
        values.add(value.toString());
        return values;
    }

    public record CsvImportError(int row, String loginId, String message) {
    }

    public record CsvImportResult(int totalCount, int createdCount, int duplicateCount, List<CsvImportError> errors) {
        public int errorCount() {
            return errors.size();
        }
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
        Member member = findById(id);

        if (actorRole != MemberRole.SUPER_ADMIN && member.getRole() == MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("ADMIN은 SUPER_ADMIN 계정을 변경할 수 없습니다.");
        }

        if (name != null && !name.trim().isEmpty()) {
            member.setName(name);
        }
        if (role != null && role != member.getRole()) {
            validateRoleAssignment(actorRole, role);
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

    private void validateRoleAssignment(MemberRole actorRole, MemberRole requestedRole) {
        if (requestedRole == MemberRole.SUPER_ADMIN && actorRole != MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("SUPER_ADMIN 권한은 SUPER_ADMIN만 부여할 수 있습니다.");
        }
    }

    /**
     * 관리자 권한 회원 삭제
     */
    @Transactional
    public void deleteMemberByAdmin(Long id) {
        Member member = findById(id);
        if (member.getRole() == MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("SUPER_ADMIN 계정은 삭제할 수 없습니다.");
        }
        memberRepository.delete(member);
        log.info("관리자 회원 삭제 완료 - ID: {}, 학번: {}", id, member.getLoginId());
    }

    /**
     * 관리자 권한 비밀번호 재설정 (임시 비밀번호 또는 초기 비활성화 상태 복구)
     * 여기서는 비밀번호를 TEMP 상태로 다시 초기화하여 계정을 비활성(isActivated = false) 상태로 만들고,
     * 사용자가 이메일 인증을 통해 다시 가입 프로세스를 밟도록 구성합니다. (완벽한 계정 리셋)
     */
    @Transactional
    public void resetMemberRegistration(Long id) {
        Member member = findById(id);
        if (member.getRole() == MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("SUPER_ADMIN 계정의 비밀번호는 관리자 도구로 초기화할 수 없습니다.");
        }

        member.setPassword(passwordEncoder.encode("TEMP_" + member.getLoginId() + "_" + System.currentTimeMillis()));
        member.setEmail(null);
        member.setActivated(false); // 가입 대기 상태로 리셋
        member.setAuthVersion(member.getAuthVersion() + 1);
        member.setFcmToken(null);
        verificationCodes.remove(member.getLoginId());
        verifiedStudents.remove(member.getLoginId());
        // 💡 관리자가 계정을 초기화한 직후에는 사용자가 바로 재인증할 수 있어야 하므로 쿨다운도 해제합니다.
        verificationResendAvailableAt.remove(member.getLoginId());
        memberRepository.save(member);
        log.info("관리자 회원 계정 재등록 초기화 완료 - ID: {}, 학번: {} (가입 대기 상태로 전환)", id, member.getLoginId());
    }

    /**
     * 관리자 회원 차단 처리 (isSuspended = true)
     */
    @Transactional
    public void suspendMember(Long id) {
        Member member = findById(id);
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
        Member member = findById(id);
        member.setSuspended(false);
        memberRepository.save(member);
        log.info("관리자 회원 차단 해제 완료 - ID: {}, 학번: {}", id, member.getLoginId());
    }
}
