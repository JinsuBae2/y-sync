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
            log.warn("FCM 활성화 실패 (firebase-adminsdk.json 파일이 없거나 잘못되었습니다. FCM 기능이 비활성화됩니다.): {}", e.getMessage());
            isInitialized = false;
        }
    }

    // 💡 개별 기기(토큰)로 푸시 알림 전송
    public void sendNotificationToToken(String token, String title, String body, Map<String, String> data) {
        if (!isInitialized) {
            log.info("FCM is disabled. Skipping sending notification to token: {}", token);
            return;
        }
        
        if (token == null || token.isEmpty()) {
            log.warn("FCM Token is empty, skipping notification.");
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
            log.debug("Successfully sent message to token: {}, response: {}", token, response);
        } catch (Exception e) {
            log.error("Error sending FCM notification to token: ", e);
        }
    }

    // 💡 전체 사용자(토픽)에게 푸시 알림 브로드캐스트
    public void sendNotificationToTopic(String topic, String title, String body, Map<String, String> data) {
        if (!isInitialized) {
            log.info("FCM is disabled. Skipping sending notification to topic: {}", topic);
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
            log.debug("Successfully sent message to topic: {}, response: {}", topic, response);
        } catch (Exception e) {
            log.error("Error sending FCM notification to topic: ", e);
        }
    }
}
