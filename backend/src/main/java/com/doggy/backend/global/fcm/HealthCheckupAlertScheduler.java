package com.doggy.backend.global.fcm;

import com.doggy.backend.domain.user.entity.PushSetting;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class HealthCheckupAlertScheduler {

    private final PushSettingRepository pushSettingRepository;
    private final FcmService fcmService;

    // 매월 1일 오전 9시 실행
    @Scheduled(cron = "0 0 9 1 * *")
    public void sendHealthCheckupAlerts() {
        List<PushSetting> settings = pushSettingRepository.findAll().stream()
                .filter(PushSetting::isHealthCheckupAlertEnabled)
                .toList();

        for (PushSetting setting : settings) {
            String fcmToken = setting.getUser().getFcmToken();
            if (fcmToken == null || fcmToken.isBlank()) continue;

            fcmService.sendToToken(
                    fcmToken,
                    "🏥 정기 건강검진 알림",
                    "이번 달 반려견 건강검진은 받으셨나요? 정기 검진으로 건강을 지켜주세요 🐶"
            );
        }
        log.info("건강검진 알림 전송 완료: {}명", settings.size());
    }
}
