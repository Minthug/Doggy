package com.doggy.backend.global.weather;

import com.doggy.backend.domain.user.entity.PushSetting;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import com.doggy.backend.global.fcm.FcmService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalTime;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class WeatherAlertScheduler {

    private final PushSettingRepository pushSettingRepository;
    private final WeatherService weatherService;
    private final FcmService fcmService;

    // 매시간 정각 실행 — 유저별 설정 시각에 맞는 유저에게만 발송
    @Scheduled(cron = "0 0 * * * *")
    public void sendWeatherAlerts() {
        int currentHour = LocalTime.now().getHour();
        log.info("날씨 알림 스케줄러 실행 (현재 {}시)", currentHour);

        List<PushSetting> settings = pushSettingRepository.findAll().stream()
                .filter(PushSetting::isWeatherAlertEnabled)
                .filter(s -> s.getWeatherAlertHour() == currentHour)
                .toList();

        if (settings.isEmpty()) return;

        // 알림 받을 유저가 있을 때만 날씨 API 호출
        WalkIndexResponse walkIndex = weatherService.getWalkIndex();
        log.info("산책 지수: {} ({}도, PM10:{}, PM2.5:{})",
                walkIndex.index(), walkIndex.temperature(), walkIndex.pm10(), walkIndex.pm25());

        if (walkIndex.index() == WalkIndex.AVOID) {
            log.info("산책 자제 날씨 - 알림 생략");
            return;
        }

        String title = walkIndex.index() == WalkIndex.GOOD
                ? "오늘 산책하기 좋아요! " + walkIndex.emoji()
                : "산책 가능하지만 주의하세요 " + walkIndex.emoji();

        String body = buildBody(walkIndex);

        int sent = 0;
        for (PushSetting setting : settings) {
            User user = setting.getUser();
            if (user.getFcmToken() == null) continue;
            try {
                fcmService.sendToToken(user.getFcmToken(), title, body);
                sent++;
            } catch (Exception e) {
                log.warn("날씨 알림 전송 실패 [userId={}]: {}", user.getId(), e.getMessage());
            }
        }

        log.info("날씨 알림 전송 완료: {}명", sent);
    }

    private String buildBody(WalkIndexResponse w) {
        StringBuilder sb = new StringBuilder();
        sb.append(String.format("기온 %d°C · 강수확률 %d%%", w.temperature(), w.precipitationProbability()));
        sb.append(String.format(" · 미세먼지 %s", w.pm10Grade()));
        if (w.index() == WalkIndex.CAUTION) {
            if (w.temperature() < 5) sb.append("\n추위에 약한 소형견은 옷을 입혀주세요 🧥");
            else if (w.temperature() > 27) sb.append("\n이른 아침이나 저녁에 산책하세요 🌙");
            else if (w.pm10() >= 80) sb.append("\n미세먼지가 나쁨 — 짧게 다녀오세요 😷");
        }
        return sb.toString();
    }
}
