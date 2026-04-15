package com.doggy.backend.global.fcm;

import com.doggy.backend.domain.user.entity.PushSetting;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class WalkReminderScheduler {

    private final WalkSessionRepository walkSessionRepository;
    private final PushSettingRepository pushSettingRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;

    // 매시간 정각 실행
    @Scheduled(cron = "0 0 * * * *")
    public void sendWalkReminders() {
        log.debug("산책 리마인더 스케줄러 실행");

        // 알림 활성화된 유저의 설정 조회
        List<PushSetting> settings = pushSettingRepository.findAll().stream()
                .filter(PushSetting::isWalkReminderEnabled)
                .toList();

        for (PushSetting setting : settings) {
            try {
                int intervalHours = setting.getReminderIntervalHours();
                LocalDateTime since = LocalDateTime.now().minusHours(intervalHours);

                // 해당 유저가 intervalHours 이내에 산책했는지 확인
                List<Long> inactiveUserIds =
                        walkSessionRepository.findUserIdsNotWalkedSince(since);

                if (!inactiveUserIds.contains(setting.getUser().getId())) continue;

                User user = setting.getUser();
                if (user.getFcmToken() == null) continue;

                String body = intervalHours >= 24
                        ? String.format("오늘 아직 산책을 안 했어요! %s와 함께 산책해볼까요?", getDogEmoji())
                        : String.format("%d시간 동안 산책을 안 했어요. 잠깐 나가볼까요?", intervalHours);

                fcmService.sendToToken(user.getFcmToken(), "산책 시간이에요 🐾", body);

            } catch (Exception e) {
                log.warn("리마인더 전송 실패 [userId={}]: {}", setting.getUser().getId(), e.getMessage());
            }
        }
    }

    private String getDogEmoji() {
        String[] emojis = {"🐶", "🐕", "🦮", "🐩"};
        return emojis[(int) (Math.random() * emojis.length)];
    }
}
