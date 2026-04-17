package com.doggy.backend.global.fcm;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class FcmService {

    public void sendToToken(String fcmToken, String title, String body) {
        sendToToken(fcmToken, title, body, Channel.WALK_REMINDER);
    }

    public void sendToToken(String fcmToken, String title, String body, Channel channel) {
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
                    // Android: 채널 지정 + heads-up 우선순위
                    .setAndroidConfig(AndroidConfig.builder()
                            .setNotification(AndroidNotification.builder()
                                    .setChannelId(channel.channelId)
                                    .build())
                            .setPriority(channel == Channel.PING
                                    ? AndroidConfig.Priority.HIGH
                                    : AndroidConfig.Priority.NORMAL)
                            .putData("channel", channel.channelId)
                            .build())
                    // iOS: 즉시 표시 (critical 아닌 일반 알림)
                    .setApnsConfig(ApnsConfig.builder()
                            .setAps(Aps.builder()
                                    .setSound("default")
                                    .build())
                            .build())
                    .build();

            String response = FirebaseMessaging.getInstance().send(message);
            log.info("FCM 전송 성공 [{}]: {}", channel.channelId, response);
        } catch (Exception e) {
            log.warn("FCM 전송 실패 [{}]: {}", title, e.getMessage());
        }
    }

    public enum Channel {
        PING("ping"),
        WALK_REMINDER("walk_reminder"),
        WEATHER("weather"),
        ACHIEVEMENT("achievement");

        public final String channelId;
        Channel(String channelId) { this.channelId = channelId; }
    }
}
