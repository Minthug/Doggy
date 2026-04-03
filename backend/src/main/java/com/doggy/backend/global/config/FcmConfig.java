package com.doggy.backend.global.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;

import jakarta.annotation.PostConstruct;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.Base64;

@Slf4j
@Configuration
public class FcmConfig {

    @Value("${fcm.credentials-path}")
    private Resource credentialsResource;

    @Value("${FCM_CREDENTIALS_BASE64:}")
    private String credentialsBase64;

    @PostConstruct
    public void initialize() {
        if (!FirebaseApp.getApps().isEmpty()) return;

        try {
            GoogleCredentials credentials;

            if (!credentialsBase64.isBlank()) {
                byte[] decoded = Base64.getDecoder().decode(credentialsBase64);
                credentials = GoogleCredentials.fromStream(new ByteArrayInputStream(decoded));
            } else if (credentialsResource.exists()) {
                credentials = GoogleCredentials.fromStream(credentialsResource.getInputStream());
            } else {
                log.warn("FCM 서비스 계정 정보가 없습니다. 푸시 알림이 비활성화됩니다.");
                return;
            }

            FirebaseApp.initializeApp(FirebaseOptions.builder().setCredentials(credentials).build());
            log.info("Firebase 초기화 완료");
        } catch (IOException e) {
            log.warn("Firebase 초기화 실패: {}", e.getMessage());
        }
    }
}
