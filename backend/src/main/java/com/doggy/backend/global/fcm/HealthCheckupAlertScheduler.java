package com.doggy.backend.global.fcm;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.user.entity.PushSetting;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@Component
@RequiredArgsConstructor
public class HealthCheckupAlertScheduler {

    private final DogRepository dogRepository;
    private final PushSettingRepository pushSettingRepository;
    private final FcmService fcmService;

    // 매월 1일 오전 9시 실행
    @Transactional(readOnly = true)
    @Scheduled(cron = "0 0 9 1 * *")
    public void sendHealthCheckupAlerts() {
        LocalDate today = LocalDate.now();
        int month = today.getMonthValue();

        List<PushSetting> settings = pushSettingRepository.findByHealthCheckupAlertEnabledTrue();

        if (settings.isEmpty()) return;

        List<Long> userIds = settings.stream().map(s -> s.getUser().getId()).toList();
        Map<Long, List<Dog>> dogsByUser = dogRepository.findAllByUserIdIn(userIds).stream()
                .collect(Collectors.groupingBy(d -> d.getUser().getId()));

        for (PushSetting setting : settings) {
            String fcmToken = setting.getUser().getFcmToken();
            if (fcmToken == null || fcmToken.isBlank()) continue;

            List<Dog> dogs = dogsByUser.getOrDefault(setting.getUser().getId(), List.of());
            if (dogs.isEmpty()) continue;

            for (Dog dog : dogs) {
                String message = buildMessage(dog, today, month);
                if (message == null) continue;

                fcmService.sendToToken(
                        fcmToken,
                        "🏥 " + dog.getName() + " 건강검진 알림",
                        message
                );
                log.info("건강검진 알림 전송: {} ({})", dog.getName(), message);
            }
        }
    }

    private String buildMessage(Dog dog, LocalDate today, int month) {
        if (dog.getBirthDate() == null) {
            // 생년월일 미등록 → 연 1회(1월)만 발송
            if (month != 1) return null;
            return dog.getName() + "의 정기 건강검진 시기예요. 올해도 건강 체크해주세요 🐾";
        }

        int ageMonths = (today.getYear() - dog.getBirthDate().getYear()) * 12
                + (today.getMonthValue() - dog.getBirthDate().getMonthValue());
        int ageYears = ageMonths / 12;

        if (ageMonths < 12) {
            // ~1세: 매월 (예방접종 및 기초검진)
            return dog.getName() + "은 아직 어린 강아지예요! 이번 달 예방접종 및 건강검진을 확인해주세요 💉";
        } else if (ageYears < 7) {
            // 1~7세: 연 1회 (1월)
            if (month != 1) return null;
            return dog.getName() + "(" + ageYears + "살)의 연간 정기 건강검진 시기예요. 올해도 건강하게! 🐶";
        } else {
            // 7세 이상: 6개월마다 (1월, 7월)
            if (month != 1 && month != 7) return null;
            return dog.getName() + "(" + ageYears + "살)은 노령견이에요. 6개월마다 정밀 건강검진을 받아주세요 ❤️";
        }
    }
}
