package com.doggy.backend.global.fcm;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class FcmService {

    public void sendToToken(String fcmToken, String title, String body) {
        if (fcmToken == null || fcmToken.isBlank()) return;
        if (FirebaseApp.getApps().isEmpty()) {
            log.debug("Firebase 미초기화 - 푸시 전송 생략: {}", title);
            return;
        }

        try {
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .build();

            String response = FirebaseMessaging.getInstance().send(message);
            log.info("FCM 전송 성공: {}", response);
        } catch (Exception e) {
            log.warn("FCM 전송 실패 [{}]: {}", title, e.getMessage());
        }
    }
}
