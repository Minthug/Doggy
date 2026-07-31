package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.entity.Dog.DogWarning;
import com.doggy.backend.domain.dog.entity.DogFavorite;
import com.doggy.backend.domain.dog.repository.DogFavoriteRepository;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.walk.entity.WalkLocation;
import com.doggy.backend.domain.walk.entity.WalkPingLog;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.repository.WalkLocationRepository;
import com.doggy.backend.domain.walk.repository.WalkPingLogRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.common.RequestLimits;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.fcm.FcmService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class WalkPingService {

    private static final double PING_RADIUS_METERS = 50.0;
    private static final int COOLDOWN_MINUTES = 5;
    private static final int STALE_SECONDS = 60;

    private final WalkSessionRepository walkSessionRepository;
    private final WalkLocationRepository walkLocationRepository;
    private final WalkPingLogRepository walkPingLogRepository;
    private final DogRepository dogRepository;
    private final DogFavoriteRepository dogFavoriteRepository;
    private final FcmService fcmService;

    @Transactional
    public void updateLocationAndPing(Long userId, Long sessionId, double lat, double lng) {
        RequestLimits.validateLatLng(lat, lng);
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

        log.info("[핑] 위치 저장 완료 — session={} user={} lat={} lng={}", sessionId, userId, lat, lng);

        // 근접 세션 탐색
        LocalDateTime staleThreshold = LocalDateTime.now().minusSeconds(STALE_SECONDS);
        List<WalkLocation> nearbyLocations = walkLocationRepository.findNearby(
                sessionId, lat, lng, PING_RADIUS_METERS, staleThreshold);

        log.info("[핑] 근접 세션 탐색 — session={} 반경={}m 유효기준={}s 이내 → {}개 발견",
                sessionId, PING_RADIUS_METERS, STALE_SECONDS, nearbyLocations.size());

        if (nearbyLocations.isEmpty()) return;

        // 근처 세션 ID 추출 후 WalkSession + User 배치 로딩
        List<Long> nearbySessionIds = nearbyLocations.stream()
                .map(wl -> wl.getWalkSession().getId())
                .toList();
        Map<Long, WalkLocation> nearbyBySessionId = walkLocationRepository
                .findBySessionIdsWithUser(nearbySessionIds).stream()
                .collect(Collectors.toMap(wl -> wl.getWalkSession().getId(), wl -> wl));

        List<Dog> myDogs = dogRepository.findAllByUserId(userId);
        Set<DogWarning> myWarnings = collectWarnings(myDogs);
        String myFcmToken = session.getUser().getFcmToken();

        if (myFcmToken == null || myFcmToken.isBlank()) {
            log.warn("[핑] 내 FCM 토큰 없음 — session={} user={}", sessionId, userId);
        }

        LocalDateTime cooldownThreshold = LocalDateTime.now().minusMinutes(COOLDOWN_MINUTES);

        // 관련 PingLog 배치 조회 → 메모리에서 쿨다운 체크
        Collection<Long> allSessionIds = new HashSet<>(nearbySessionIds);
        allSessionIds.add(sessionId);
        Set<String> recentPingKeys = walkPingLogRepository
                .findRecentBySessionIds(allSessionIds, cooldownThreshold).stream()
                .map(pl -> pl.getSessionAId() + "-" + pl.getSessionBId())
                .collect(Collectors.toSet());

        List<WalkLocation> validNearby = nearbyLocations.stream()
                .filter(nearby -> {
                    Long nearbySessionId = nearby.getWalkSession().getId();
                    Long a = Math.min(sessionId, nearbySessionId);
                    Long b = Math.max(sessionId, nearbySessionId);
                    if (recentPingKeys.contains(a + "-" + b)) {
                        log.info("[핑] 쿨다운 스킵 — session {} ↔ session {}", sessionId, nearbySessionId);
                        return false;
                    }
                    return true;
                })
                .toList();

        if (validNearby.isEmpty()) return;

        // 근처 유저 경고 배치 수집
        List<Long> validNearbyUserIds = validNearby.stream()
                .map(nearby -> nearbyBySessionId.get(nearby.getWalkSession().getId()))
                .filter(wl -> wl != null)
                .map(wl -> wl.getWalkSession().getUser().getId())
                .toList();
        Set<DogWarning> allNearbyWarnings = collectWarnings(dogRepository.findAllByUserIdIn(validNearbyUserIds));

        if (myFcmToken != null && !myFcmToken.isBlank()) {
            sendAggregatedPingNotification(myFcmToken, validNearby.size(), allNearbyWarnings);
            log.info("[핑] 집계 알림 발송 — session={} 근처={}마리 경고={}", sessionId, validNearby.size(), allNearbyWarnings);
        }

        // 기존 PingLog 배치 조회 (upsert용)
        List<Long> validSessionIds = validNearby.stream()
                .map(wl -> wl.getWalkSession().getId())
                .toList();
        Map<String, WalkPingLog> existingLogs = walkPingLogRepository
                .findAllBySessionIds(validSessionIds).stream()
                .collect(Collectors.toMap(
                        pl -> pl.getSessionAId() + "-" + pl.getSessionBId(),
                        pl -> pl
                ));

        // 즐겨찾기 배치 조회: 근처 유저들이 내 강아지를 즐겨찾기했는지 확인
        List<Long> myDogIds = myDogs.stream().map(Dog::getId).toList();
        Map<Long, List<Dog>> favoritedMyDogsByNearbyUser = myDogIds.isEmpty()
                ? Map.of()
                : dogFavoriteRepository.findByUserIdInAndDogIdIn(validNearbyUserIds, myDogIds)
                        .stream()
                        .collect(Collectors.groupingBy(
                                f -> f.getUser().getId(),
                                Collectors.mapping(DogFavorite::getDog, Collectors.toList())
                        ));

        // 각 근처 유저에게 알림 + PingLog 일괄 저장
        List<WalkPingLog> logsToSave = new ArrayList<>();
        for (WalkLocation nearby : validNearby) {
            Long nearbySessionId = nearby.getWalkSession().getId();
            WalkLocation nearbyWithUser = nearbyBySessionId.get(nearbySessionId);
            if (nearbyWithUser == null) continue;
            Long nearbyUserId = nearbyWithUser.getWalkSession().getUser().getId();
            String nearbyFcmToken = nearbyWithUser.getWalkSession().getUser().getFcmToken();

            if (nearbyFcmToken != null && !nearbyFcmToken.isBlank()) {
                List<Dog> favoritedDogs = favoritedMyDogsByNearbyUser.get(nearbyUserId);
                if (favoritedDogs != null && !favoritedDogs.isEmpty()) {
                    sendFavoriteDogPingNotification(nearbyFcmToken, favoritedDogs);
                } else {
                    sendPingNotification(nearbyFcmToken, myWarnings);
                }
            } else {
                log.warn("[핑] 상대방 FCM 토큰 없음 — nearbySession={}", nearbySessionId);
            }

            Long a = Math.min(sessionId, nearbySessionId);
            Long b = Math.max(sessionId, nearbySessionId);
            WalkPingLog pingLog = existingLogs.getOrDefault(a + "-" + b,
                    WalkPingLog.builder().sessionAId(a).sessionBId(b).build());
            pingLog.refresh();
            logsToSave.add(pingLog);

            log.info("[핑] 발송 완료 — session {} ↔ session {}", sessionId, nearbySessionId);
        }
        walkPingLogRepository.saveAll(logsToSave);
    }

    @Transactional
    public void removeLocation(Long sessionId) {
        walkLocationRepository.deleteByWalkSession_Id(sessionId);
        log.info("[핑] 위치 제거 — session={}", sessionId);
    }

    private void sendAggregatedPingNotification(String fcmToken, int count, Set<DogWarning> warnings) {
        String title = "🐾 근처에 강아지 " + count + "마리가 있어요!";
        String body;
        if (!warnings.isEmpty()) {
            String warningText = warnings.stream()
                    .map(this::warningLabel)
                    .collect(Collectors.joining(", "));
            body = "50m 내에 " + count + "마리가 있어요 (⚠️ " + warningText + " 포함)";
        } else {
            body = "50m 내에 " + count + "마리의 강아지가 있어요.";
        }
        fcmService.sendToToken(fcmToken, title, body, FcmService.Channel.PING);
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

    private void sendFavoriteDogPingNotification(String fcmToken, List<Dog> favoritedDogs) {
        String dogNames = favoritedDogs.stream()
                .map(Dog::getName)
                .collect(Collectors.joining(", "));
        String title = "⭐ 즐겨찾기 강아지가 근처에 있어요!";
        String body = dogNames + "이(가) 50m 내에 있어요!";
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
