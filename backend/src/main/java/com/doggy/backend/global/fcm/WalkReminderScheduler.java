package com.doggy.backend.global.fcm;

import com.doggy.backend.domain.user.entity.PushSetting;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Component
@RequiredArgsConstructor
public class WalkReminderScheduler {

    private final WalkSessionRepository walkSessionRepository;
    private final PushSettingRepository pushSettingRepository;
    private final FcmService fcmService;

    // 매시간 정각 실행
    @Transactional(readOnly = true)
    @Scheduled(cron = "0 0 * * * *")
    public void sendWalkReminders() {
        log.debug("산책 리마인더 스케줄러 실행");

        List<PushSetting> settings = pushSettingRepository.findWalkReminderTargets();
        if (settings.isEmpty()) return;

        // intervalHours가 같은 유저끼리 묶어 쿼리 횟수를 고유 interval 수로 줄임
        Map<Integer, List<PushSetting>> byInterval = settings.stream()
                .collect(Collectors.groupingBy(PushSetting::getReminderIntervalHours));

        LocalDateTime now = LocalDateTime.now();
        for (Map.Entry<Integer, List<PushSetting>> entry : byInterval.entrySet()) {
            int intervalHours = entry.getKey();
            LocalDateTime since = now.minusHours(intervalHours);

            Set<Long> inactiveUserIds = new java.util.HashSet<>(
                    walkSessionRepository.findUserIdsNotWalkedSince(since));

            String body = intervalHours >= 24
                    ? String.format("오늘 아직 산책을 안 했어요! %s와 함께 산책해볼까요?", getDogEmoji())
                    : String.format("%d시간 동안 산책을 안 했어요. 잠깐 나가볼까요?", intervalHours);

            for (PushSetting setting : entry.getValue()) {
                User user = setting.getUser();
                if (!inactiveUserIds.contains(user.getId())) continue;
                if (user.getFcmToken() == null) continue;
                try {
                    fcmService.sendToToken(user.getFcmToken(), "산책 시간이에요 🐾", body);
                } catch (Exception e) {
                    log.warn("리마인더 전송 실패 [userId={}]: {}", user.getId(), e.getMessage());
                }
            }
        }
    }

    private String getDogEmoji() {
        String[] emojis = {"🐶", "🐕", "🦮", "🐩"};
        return emojis[(int) (Math.random() * emojis.length)];
    }
}
