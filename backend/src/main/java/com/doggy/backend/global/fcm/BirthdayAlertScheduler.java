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
public class BirthdayAlertScheduler {

    private final DogRepository dogRepository;
    private final PushSettingRepository pushSettingRepository;
    private final FcmService fcmService;

    // 매일 오전 8시 실행
    @Transactional(readOnly = true)
    @Scheduled(cron = "0 0 8 * * *")
    public void sendBirthdayAlerts() {
        LocalDate today = LocalDate.now();
        List<Dog> birthdayDogs = dogRepository.findByBirthMonthAndDay(today.getMonthValue(), today.getDayOfMonth());

        if (birthdayDogs.isEmpty()) return;

        Map<Long, PushSetting> settingMap = pushSettingRepository.findAllWithUser().stream()
                .collect(Collectors.toMap(s -> s.getUser().getId(), s -> s));

        for (Dog dog : birthdayDogs) {
            Long userId = dog.getUser().getId();
            PushSetting setting = settingMap.get(userId);
            if (setting == null || !setting.isBirthdayAlertEnabled()) continue;

            String fcmToken = dog.getUser().getFcmToken();
            if (fcmToken == null || fcmToken.isBlank()) continue;

            int age = today.getYear() - dog.getBirthDate().getYear();
            fcmService.sendToToken(
                    fcmToken,
                    "🎂 " + dog.getName() + "의 생일이에요!",
                    dog.getName() + "이(가) 오늘 " + age + "살이 됐어요! 생일을 축하해주세요 🐾"
            );
            log.info("생일 알림 전송: {} ({}살)", dog.getName(), age);
        }
    }
}
