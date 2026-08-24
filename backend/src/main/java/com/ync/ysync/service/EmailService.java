package com.ync.ysync.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmailService {

    private final JavaMailSender mailSender;

    /**
     * 영남이공대학교 학생 메일(studentId@ync.ac.kr)로 가입 인증코드를 발송합니다.
     * SMTP 전송 오류가 발생하더라도 로컬 개발 환경 편의를 위해 로그를 출력하고 정상 처리되는 폴백을 제공합니다.
     */
    public void sendVerificationCode(String toEmail, String code) {
        log.info("인증 이메일 발송 시도 - 수신자: {}", toEmail);
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setTo(toEmail);
            message.setSubject("[Y-Sync] 영남이공대학교 모바일 학생 커뮤니티 가입 인증 번호");
            message.setText("안녕하세요. 영남이공대학교 소프트웨어융합과 모바일 학생 커뮤니티 Y-Sync입니다.\n\n" +
                    "회원가입 본인 인증을 위한 6자리 인증 번호는 다음과 같습니다.\n\n" +
                    "인증 번호: [" + code + "]\n\n" +
                    "인증 번호 입력 유효 시간은 5분입니다. 시간 내에 입력해주세요.\n\n" +
                    "감사합니다.");
            mailSender.send(message);
            log.info("인증 이메일 전송 완료 - 수신자: {}", toEmail);
        } catch (Exception e) {
            log.error("❌ SMTP 메일 전송 실패 (Gmail SMTP 환경 변수가 설정되지 않았거나 네트워크 문제일 수 있습니다.)", e);
            throw new IllegalArgumentException("이메일 발송에 실패했습니다. 메일 주소를 확인하거나 잠시 후 다시 시도해 주세요.", e);
        }
    }
}
