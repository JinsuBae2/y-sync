package com.ync.ysync.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.util.Map;

@Slf4j
@Service
public class FCMService {

    @Value("${firebase.config.path}")
    private Resource firebaseConfig;

    private boolean isInitialized = false; // 💡 FCM 초기화 여부 플래그

    @PostConstruct
    public void initialize() {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                InputStream serviceAccount = firebaseConfig.getInputStream();
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();

                FirebaseApp.initializeApp(options);
                log.info("Firebase application initialized successfully.");
            }
            isInitialized = true;
        } catch (Exception e) {
            // 💡 [FCM 로그 개선] 초기화 실패 오류 상세 로그 출력
            log.error("[FCM] Firebase 초기화 실패 (FCM 기능 비활성화) - 사유: {}", e.getMessage(), e);
            isInitialized = false;
        }
    }

    // 💡 개별 기기(토큰)로 푸시 알림 전송
    public void sendNotificationToToken(String token, String title, String body, Map<String, String> data) {
        if (!isInitialized) {
            // 💡 [FCM 로그 개선] 비활성화 시 로그 기록
            log.info("[FCM] FCM이 비활성화 상태입니다. 알림 전송을 건너뜁니다. 수신 토큰: {}", token);
            return;
        }
        
        if (token == null || token.isEmpty()) {
            // 💡 [FCM 로그 개선] 토큰 유무 확인 로그 기록 (INFO 레벨)
            log.info("[FCM] 수신자 FCM 토큰이 비어있어 알림 전송을 건너뜁니다. 제목: {}", title);
            return;
        }
        
        try {
            Message.Builder messageBuilder = Message.builder()
                    .setToken(token)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build());

            if (data != null && !data.isEmpty()) {
                messageBuilder.putAllData(data);
            }

            String response = FirebaseMessaging.getInstance().send(messageBuilder.build());
            // 💡 [FCM 로그 개선] 성공 여부 INFO 레벨로 명확하게 노출
            log.info("[FCM] 개별 토큰 알림 발송 성공 - 수신 토큰: {}..., 제목: {}, response: {}", 
                    token.substring(0, Math.min(token.length(), 20)), title, response);
        } catch (Exception e) {
            // 💡 [FCM 로그 개선] 실패한 경우에도 상세 내용을 INFO 및 ERROR 형태로 확실하게 기록
            log.error("[FCM] 개별 토큰 알림 발송 실패 - 수신 토큰: {}, 제목: {}, 사유: {}", token, title, e.getMessage(), e);
        }
    }

    // 💡 전체 사용자(토픽)에게 푸시 알림 브로드캐스트
    public void sendNotificationToTopic(String topic, String title, String body, Map<String, String> data) {
        if (!isInitialized) {
            // 💡 [FCM 로그 개선] 비활성화 시 로그 기록
            log.info("[FCM] FCM이 비활성화 상태입니다. 토픽 알림 전송을 건너뜁니다. 토픽: {}", topic);
            return;
        }
        
        try {
            Message.Builder messageBuilder = Message.builder()
                    .setTopic(topic)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build());

            if (data != null && !data.isEmpty()) {
                messageBuilder.putAllData(data);
            }

            String response = FirebaseMessaging.getInstance().send(messageBuilder.build());
            // 💡 [FCM 로그 개선] 성공 여부 INFO 레벨로 명확하게 노출
            log.info("[FCM] 토픽 알림 발송 성공 - 토픽: {}, 제목: {}, response: {}", topic, title, response);
        } catch (Exception e) {
            // 💡 [FCM 로그 개선] 실패한 경우에도 상세 내용을 INFO 및 ERROR 형태로 확실하게 기록
            log.error("[FCM] 토픽 알림 발송 실패 - 토픽: {}, 제목: {}, 사유: {}", topic, title, e.getMessage(), e);
        }
    }
}
