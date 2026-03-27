package com.doggy.backend.global.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;

import jakarta.annotation.PostConstruct;
import java.io.IOException;

@Slf4j
@Configuration
public class FcmConfig {

    @Value("${fcm.credentials-path}")
    private Resource credentialsResource;

    @PostConstruct
    public void initialize() {
        if (!credentialsResource.exists()) {
            log.warn("FCM 서비스 계정 파일이 없습니다. 푸시 알림이 비활성화됩니다. ({} 경로에 파일을 추가하세요)", credentialsResource);
            return;
        }

        if (!FirebaseApp.getApps().isEmpty()) return;

        try {
            GoogleCredentials credentials = GoogleCredentials
                    .fromStream(credentialsResource.getInputStream());

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(credentials)
                    .build();

            FirebaseApp.initializeApp(options);
            log.info("Firebase 초기화 완료");
        } catch (IOException e) {
            log.warn("Firebase 초기화 실패: {}", e.getMessage());
        }
    }
}
