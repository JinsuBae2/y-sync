package com.ync.ysync.service;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicReference;

/**
 * 💡 이메일 인증번호와 가입 증표의 발급·검증을 담당합니다.
 *
 * `MemberService`에서 분리한 이유는 길이보다 **상태** 때문입니다. 아래 세 개의 인메모리 맵이
 * 이 클래스의 전부이고, 회원 조회나 비밀번호 같은 다른 관심사와 섞이면 원자성 보장이 어디까지인지
 * 읽어내기 어려워집니다. 여기서는 맵을 건드리는 코드가 한 파일 안에 모두 있습니다.
 *
 * 바깥에 노출하는 것은 네 개의 동작뿐이며, 내부 값 타입은 새어 나가지 않습니다.
 * 호출자는 "인증된 이메일"만 돌려받습니다.
 *
 * ⚠️ 상태가 인스턴스 메모리에 있으므로 서버를 여러 대로 늘리면 인증이 깨집니다.
 *    지금은 단일 인스턴스 운영이라 유효하며, 확장 시 공유 저장소로 옮겨야 합니다.
 */
@Slf4j
@Service
public class MemberVerificationService {

    /** 인증번호 목적입니다. 가입용 코드로 비밀번호를 재설정하는 교차 사용을 막습니다. */
    public enum Purpose {
        SIGNUP,
        PASSWORD_RESET
    }

    // 💡 인증번호는 한 번 발급된 뒤 5분간 고정되므로, 시도 횟수를 제한하지 않으면 6자리(10^6)를
    //    무차별 대입할 수 있습니다. 아래 상수로 challenge당 시도 횟수와 재발급 간격을 제한합니다.
    private static final int MAX_VERIFICATION_ATTEMPTS = 5;
    private static final int VERIFICATION_TTL_MINUTES = 5;
    private static final int RESEND_COOLDOWN_SECONDS = 60;
    private static final int SIGNUP_GRANT_TTL_MINUTES = 10;

    private final ConcurrentHashMap<String, VerificationInfo> verificationCodes = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, VerifiedInfo> verifiedStudents = new ConcurrentHashMap<>();
    // 💡 재발급 가능 시각. challenge가 시도 초과로 삭제돼도 남아야 "5회 실패 → 즉시 재발급 → 5회 더"
    //    방식의 우회를 막을 수 있으므로 별도로 보관합니다. 키가 학번이라 크기는 회원 수로 제한됩니다.
    private final ConcurrentHashMap<String, LocalDateTime> verificationResendAvailableAt = new ConcurrentHashMap<>();
    private final SecureRandom secureRandom = new SecureRandom();

    /**
     * 💡 인증번호를 발급하고 저장합니다.
     *
     * 재발급은 {@link #RESEND_COOLDOWN_SECONDS}초 간격으로 제한합니다. 이 제한이 없으면
     * "시도 횟수를 소진한 뒤 즉시 재발급"을 반복해 시도 제한을 그대로 우회할 수 있고,
     * 메일 발송 할당량도 무제한으로 소모됩니다. 새 코드를 넣으면 기존 challenge는 폐기됩니다.
     */
    public String issueCode(String loginId, String toEmail, Purpose purpose) {
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
     * 💡 인증번호를 원자적으로 검증하고 소비합니다. 성공 시 인증된 이메일을 반환합니다.
     *
     * 조회·검증·시도 횟수 증가·삭제를 {@code compute} 한 번으로 묶습니다. 이전 구현은
     * `get → 검증 → remove` 구조라 같은 코드로 거의 동시에 들어온 두 요청이 모두 통과할 수
     * 있었고, 비밀번호 재설정에서는 서로 다른 비밀번호가 경쟁할 수 있었습니다.
     *
     * 이메일을 돌려주는 이유: 호출자가 인증된 주소를 중간 저장소를 거치지 않고 바로 받을 수 있어,
     * 비밀번호 재설정이 통과 기록 맵에 의존하지 않게 됩니다.
     */
    public String consumeCode(String loginId, String code, Purpose purpose) {
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
        return consumed.get().getEmail();
    }

    /**
     * 💡 가입 인증 통과 기록을 남기고, 추측 불가능한 증표를 발급해 반환합니다.
     *
     * 가입은 인증과 최종 제출이 분리된 흐름이라 통과 기록이 필요합니다. 이때 학번만 남기면
     * 누가 인증했는지 알 수 없으므로, 증표를 함께 발급해 인증한 주체에게만 돌려줍니다.
     * 가입 요청은 이 증표를 제시해야 하며, 증표는 한 번 쓰면 즉시 폐기됩니다.
     */
    public String issueSignupGrant(String loginId, String verifiedEmail) {
        byte[] bytes = new byte[32]; // 256비트 난수를 URL 안전 형식으로 인코딩합니다.
        secureRandom.nextBytes(bytes);
        String grant = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);

        verifiedStudents.put(loginId, new VerifiedInfo(
                LocalDateTime.now().plusMinutes(SIGNUP_GRANT_TTL_MINUTES),
                verifiedEmail, Purpose.SIGNUP, grant));
        purgeExpiredSignupGrants();
        return grant;
    }

    /**
     * 💡 제시된 증표를 원자적으로 검증하고 소비합니다. 성공 시 인증된 이메일을 반환합니다.
     *
     * 같은 증표로 거의 동시에 들어온 요청이 둘 다 통과하지 않도록, 조회·검증·삭제를
     * {@code compute} 한 번으로 묶어 최대 한 번만 성공하게 합니다.
     */
    public String consumeSignupGrant(String loginId, String grant) {
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
            if (info.getPurpose() != Purpose.SIGNUP) {
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
        return consumed.get().getEmail();
    }

    /**
     * 💡 한 학번의 인증 상태를 모두 지웁니다. 관리자가 계정을 재등록 초기화할 때 씁니다.
     *
     * 재발급 쿨다운까지 함께 지웁니다. 초기화 직후에는 사용자가 바로 재인증할 수 있어야 합니다.
     */
    public void clear(String loginId) {
        verificationCodes.remove(loginId);
        verifiedStudents.remove(loginId);
        verificationResendAvailableAt.remove(loginId);
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

    /** 💡 증표 비교는 길이·내용 모두 시간 정보를 흘리지 않도록 상수 시간으로 수행합니다. */
    private boolean constantTimeEquals(String expected, String actual) {
        if (expected == null || actual == null) {
            return false;
        }
        return java.security.MessageDigest.isEqual(
                expected.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                actual.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    private String generateVerificationCode() {
        return String.format("%06d", secureRandom.nextInt(1_000_000));
    }

    /**
     * 💡 `consumeCode`의 판정 결과입니다. `ConcurrentHashMap.compute`의 remapping function 안에서
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

    /** 💡 가입 증표 판정 결과입니다. {@code compute} 안에서 예외를 던지지 않기 위해 분리합니다. */
    private enum GrantOutcome {
        NOT_FOUND,
        EXPIRED,
        PURPOSE_MISMATCH,
        GRANT_MISMATCH,
        SUCCESS
    }

    @Getter
    @AllArgsConstructor
    private static class VerificationInfo {
        private final String code;
        private final LocalDateTime expiredAt;
        private final String email;
        private final Purpose purpose;
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
        private final Purpose purpose;
        // 💡 인증을 통과한 주체에게만 발급하는 증표입니다. 이 값이 없으면 통과 기록이 학번만으로
        //    식별되어, 학번과 이름만 아는 제3자가 남의 인증 결과로 가입을 완료할 수 있습니다.
        private final String grant;
    }
}
