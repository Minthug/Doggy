package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.entity.Dog.DogWarning;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.walk.entity.WalkLocation;
import com.doggy.backend.domain.walk.entity.WalkPingLog;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.repository.WalkLocationRepository;
import com.doggy.backend.domain.walk.repository.WalkPingLogRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.fcm.FcmService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class WalkPingService {

    private static final double PING_RADIUS_METERS = 50.0;
    private static final int COOLDOWN_MINUTES = 5;
    // 30초 이내에 갱신된 위치만 유효
    private static final int STALE_SECONDS = 30;

    private final WalkSessionRepository walkSessionRepository;
    private final WalkLocationRepository walkLocationRepository;
    private final WalkPingLogRepository walkPingLogRepository;
    private final DogRepository dogRepository;
    private final FcmService fcmService;

    @Transactional
    public void updateLocationAndPing(Long userId, Long sessionId, double lat, double lng) {
        WalkSession session = walkSessionRepository.findById(sessionId)
                .orElseThrow(() -> BusinessException.notFound("산책 세션을 찾을 수 없습니다"));

        if (!session.getUser().getId().equals(userId)) {
            throw BusinessException.badRequest("본인의 산책 세션이 아닙니다");
        }
        if (session.getStatus() == WalkSession.Status.COMPLETED) {
            throw BusinessException.badRequest("완료된 산책 세션입니다");
        }

        // 위치 저장 (upsert)
        WalkLocation location = walkLocationRepository.findByWalkSession_Id(sessionId)
                .orElseGet(() -> WalkLocation.builder().walkSession(session).lat(lat).lng(lng).build());
        location.update(lat, lng);
        walkLocationRepository.save(location);

        // 근접 세션 탐색
        LocalDateTime staleThreshold = LocalDateTime.now().minusSeconds(STALE_SECONDS);
        List<WalkLocation> nearbyLocations = walkLocationRepository.findNearby(
                sessionId, lat, lng, PING_RADIUS_METERS, staleThreshold);

        if (nearbyLocations.isEmpty()) return;

        List<Dog> myDogs = dogRepository.findAllByUserId(userId);
        Set<DogWarning> myWarnings = collectWarnings(myDogs);
        String myFcmToken = session.getUser().getFcmToken();

        for (WalkLocation nearby : nearbyLocations) {
            WalkSession nearbySession = nearby.getWalkSession();
            Long nearbySessionId = nearbySession.getId();

            // 쿨다운 확인 (쌍을 항상 작은 id → 큰 id 순서로 저장)
            Long a = Math.min(sessionId, nearbySessionId);
            Long b = Math.max(sessionId, nearbySessionId);
            LocalDateTime cooldownThreshold = LocalDateTime.now().minusMinutes(COOLDOWN_MINUTES);

            if (walkPingLogRepository.existsBySessionAIdAndSessionBIdAndPingedAtAfter(a, b, cooldownThreshold)) {
                continue;
            }

            Long nearbyUserId = nearbySession.getUser().getId();
            List<Dog> nearbyDogs = dogRepository.findAllByUserId(nearbyUserId);
            Set<DogWarning> nearbyWarnings = collectWarnings(nearbyDogs);
            String nearbyFcmToken = nearbySession.getUser().getFcmToken();

            // 나에게: 상대방 경고 정보 포함
            sendPingNotification(myFcmToken, nearbyWarnings);
            // 상대방에게: 내 경고 정보 포함
            sendPingNotification(nearbyFcmToken, myWarnings);

            // 핑 로그 저장/갱신
            WalkPingLog pingLog = walkPingLogRepository.findBySessionAIdAndSessionBId(a, b)
                    .orElseGet(() -> WalkPingLog.builder().sessionAId(a).sessionBId(b).build());
            pingLog.refresh();
            walkPingLogRepository.save(pingLog);

            log.debug("산책 핑 발송: session {} ↔ session {}", sessionId, nearbySessionId);
        }
    }

    @Transactional
    public void removeLocation(Long sessionId) {
        walkLocationRepository.deleteByWalkSession_Id(sessionId);
    }

    private void sendPingNotification(String fcmToken, Set<DogWarning> nearbyWarnings) {
        if (fcmToken == null || fcmToken.isBlank()) return;

        String title;
        String body;

        if (!nearbyWarnings.isEmpty()) {
            String warningText = nearbyWarnings.stream()
                    .map(this::warningLabel)
                    .collect(Collectors.joining(", "));
            title = "⚠️ 주의! 근처에 특이사항 강아지가 있어요";
            body = "[" + warningText + "] 강아지가 50m 내에 있어요!";
        } else {
            title = "🐾 근처에 강아지가 있어요!";
            body = "50m 내에 다른 강아지가 있어요.";
        }

        fcmService.sendToToken(fcmToken, title, body, FcmService.Channel.PING);
    }

    private Set<DogWarning> collectWarnings(List<Dog> dogs) {
        return dogs.stream()
                .flatMap(d -> d.getWarnings().stream())
                .collect(Collectors.toSet());
    }

    private String warningLabel(DogWarning warning) {
        return switch (warning) {
            case AGGRESSIVE -> "사나움";
            case BITING -> "물림 주의";
            case JUMPING -> "달려듦";
            case ESCAPING -> "도주 주의";
            case BARKING -> "짖음 주의";
        };
    }
}
