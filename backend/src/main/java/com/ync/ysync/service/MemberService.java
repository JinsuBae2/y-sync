package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
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

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class MemberService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    // 💡 인증 코드 및 가입 허가 정보를 담을 인메모리 스토리지
    private final ConcurrentHashMap<String, VerificationInfo> verificationCodes = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, VerifiedInfo> verifiedStudents = new ConcurrentHashMap<>();
    private final SecureRandom secureRandom = new SecureRandom();

    private enum VerificationPurpose {
        SIGNUP,
        PASSWORD_RESET
    }

    @Getter
    @AllArgsConstructor
    private static class VerificationInfo {
        private final String code;
        private final LocalDateTime expiredAt;
        private final String email;
        private final VerificationPurpose purpose;
    }

    @Getter
    @AllArgsConstructor
    private static class VerifiedInfo {
        private final LocalDateTime expiredAt;
        private final String email;
        private final VerificationPurpose purpose;
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

        // 2. 6자리 인증번호 생성
        String code = generateVerificationCode();
        LocalDateTime expiredAt = LocalDateTime.now().plusMinutes(5); // 5분 유효

        verificationCodes.put(loginId,
                new VerificationInfo(code, expiredAt, toEmail, VerificationPurpose.SIGNUP));

        // 3. 이메일 발송
        emailService.sendVerificationCode(toEmail, code);
    }

    /**
     * 인증번호 검증
     */
    public boolean verifySignupCode(String loginId, String code) {
        verifyCode(loginId, code, VerificationPurpose.SIGNUP);
        return true;
    }

    private void verifyCode(String loginId, String code, VerificationPurpose purpose) {
        VerificationInfo info = verificationCodes.get(loginId);
        if (info == null) {
            throw new IllegalArgumentException("인증 요청 기록이 없거나 만료되었습니다.");
        }

        if (info.getExpiredAt().isBefore(LocalDateTime.now())) {
            verificationCodes.remove(loginId);
            throw new IllegalArgumentException("인증 시간이 만료되었습니다. 다시 시도해주세요.");
        }

        if (!info.getCode().equals(code)) {
            throw new IllegalArgumentException("인증 번호가 일치하지 않습니다.");
        }

        if (info.getPurpose() != purpose) {
            throw new IllegalArgumentException("인증 목적이 올바르지 않습니다. 인증번호를 다시 요청해 주세요.");
        }

        // 인증 통과 기록 저장 (10분간 유효)
        verifiedStudents.put(loginId,
                new VerifiedInfo(LocalDateTime.now().plusMinutes(10), info.getEmail(), purpose));
        verificationCodes.remove(loginId);
        log.info("인증 성공 - 학번: {}, 목적: {}", loginId, purpose);
    }

    /**
     * 최종 회원가입 및 계정 활성화
     */
    @Transactional
    public Member signup(String loginId, String password, String name) {
        // 1. 이메일 인증 통과 여부 검증
        VerifiedInfo verifiedInfo = verifiedStudents.get(loginId);
        if (verifiedInfo == null || verifiedInfo.getExpiredAt().isBefore(LocalDateTime.now())
                || verifiedInfo.getPurpose() != VerificationPurpose.SIGNUP) {
            verifiedStudents.remove(loginId);
            throw new IllegalArgumentException("이메일 인증이 완료되지 않았거나 인증 시간이 초과되었습니다.");
        }

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

        // 인증 성공 만료 처리
        verifiedStudents.remove(loginId);
        log.info("회원 가입 완료 - 학번: {}, 이름: {}", loginId, name);

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

        String code = generateVerificationCode();
        verificationCodes.put(member.getLoginId(),
                new VerificationInfo(code, LocalDateTime.now().plusMinutes(5), member.getEmail(),
                        VerificationPurpose.PASSWORD_RESET));
        emailService.sendPasswordResetCode(member.getEmail(), code);
    }

    @Transactional
    public void confirmPasswordReset(String loginId, String code, String newPassword) {
        validatePassword(newPassword);
        verifyCode(loginId, code, VerificationPurpose.PASSWORD_RESET);

        VerifiedInfo verifiedInfo = verifiedStudents.get(loginId);
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException("등록된 계정을 찾을 수 없습니다."));
        if (verifiedInfo == null || !verifiedInfo.getEmail().equals(member.getEmail())) {
            verifiedStudents.remove(loginId);
            throw new IllegalArgumentException("인증 정보가 일치하지 않습니다. 다시 시도해 주세요.");
        }

        member.setPassword(passwordEncoder.encode(newPassword));
        member.setAuthVersion(member.getAuthVersion() + 1);
        member.setFcmToken(null);
        verifiedStudents.remove(loginId);
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
    public Member createMemberByAdmin(String loginId, String name, MemberRole role) {
        // 이미 등록된 학번인 경우
        if (memberRepository.findByLoginId(loginId).isPresent()) {
            throw new IllegalArgumentException("이미 등록되었거나 사용 중인 학번입니다.");
        }

        Member member = Member.builder()
                .loginId(loginId)
                .password(passwordEncoder.encode("TEMP_" + loginId + "_" + System.currentTimeMillis())) // 임시 비밀번호 (로그인
                                                                                                        // 불가능 상태 유도)
                .name(name)
                .role(role != null ? role : MemberRole.USER)
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
    public void createMembersByCsv(InputStream csvStream) {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(csvStream, StandardCharsets.UTF_8))) {
            String line;
            boolean isFirstLine = true;
            int successCount = 0;

            while ((line = reader.readLine()) != null) {
                if (line.trim().isEmpty())
                    continue;

                // UTF-8 BOM 제거
                if (isFirstLine && line.startsWith("\uFEFF")) {
                    line = line.substring(1);
                }

                String[] parts = line.split(",");
                if (parts.length < 2)
                    continue;

                String loginId = parts[0].trim();
                String name = parts[1].trim();

                // 첫 행 헤더 필터링
                if (isFirstLine && (loginId.contains("학번") || loginId.equalsIgnoreCase("loginid")
                        || loginId.equalsIgnoreCase("studentId"))) {
                    isFirstLine = false;
                    continue;
                }
                isFirstLine = false;

                // 학번은 숫자만 포함되어야 함
                if (!loginId.matches("^\\d+$")) {
                    log.warn("CSV 파싱 - 올바르지 않은 학번 형식 건너뜀: {}", loginId);
                    continue;
                }

                MemberRole role = MemberRole.USER;
                if (parts.length >= 3) {
                    try {
                        role = MemberRole.valueOf(parts[2].trim().toUpperCase());
                    } catch (IllegalArgumentException e) {
                        // ignore
                    }
                }

                // 중복 회원 건너뛰기
                if (memberRepository.findByLoginId(loginId).isEmpty()) {
                    Member member = Member.builder()
                            .loginId(loginId)
                            .password(passwordEncoder.encode("TEMP_" + loginId + "_" + System.currentTimeMillis()))
                            .name(name)
                            .role(role)
                            .isActivated(false)
                            .provider(AuthProvider.LOCAL)
                            .authType(AuthType.PASSWORD)
                            .build();
                    memberRepository.save(member);
                    successCount++;
                }
            }
            log.info("CSV 일괄 학생 사전등록 완료 - 총 {}명 등록 완료", successCount);
        } catch (Exception e) {
            throw new RuntimeException("CSV 파일 파싱 및 등록 중 오류가 발생했습니다: " + e.getMessage(), e);
        }
    }

    /**
     * 관리자 권한 회원 정보 수정 (이름, 권한)
     */
    @Transactional
    public Member updateMemberByAdmin(Long id, String name, MemberRole role) {
        Member member = findById(id);

        if (name != null && !name.trim().isEmpty()) {
            member.setName(name);
        }
        if (role != null) {
            member.setRole(role);
        }

        log.info("관리자 회원정보 수정 완료 - ID: {}, 수정된 이름: {}, 권한: {}", id, member.getName(), member.getRole());
        return memberRepository.save(member);
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
