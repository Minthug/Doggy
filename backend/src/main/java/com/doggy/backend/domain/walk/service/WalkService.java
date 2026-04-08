package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.dto.*;
import com.doggy.backend.domain.walk.entity.WalkPoint;
import com.doggy.backend.domain.walk.entity.WalkRouteBookmark;
import com.doggy.backend.domain.walk.entity.WalkRouteLike;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;
import com.doggy.backend.domain.walk.repository.WalkPointRepository;
import com.doggy.backend.domain.walk.repository.WalkRouteBookmarkRepository;
import com.doggy.backend.domain.walk.repository.WalkRouteLikeRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.fcm.FcmService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WalkService {

    private final WalkSessionRepository walkSessionRepository;
    private final WalkPointRepository walkPointRepository;
    private final WalkRouteLikeRepository likeRepository;
    private final WalkRouteBookmarkRepository bookmarkRepository;
    private final UserRepository userRepository;
    private final DogRepository dogRepository;
    private final PushSettingRepository pushSettingRepository;
    private final FcmService fcmService;

    @Transactional
    public WalkSessionResponse start(Long userId) {
        walkSessionRepository.findActiveSession(userId, Status.IN_PROGRESS).ifPresent(s -> {
            throw BusinessException.badRequest("이미 진행 중인 산책이 있습니다");
        });

        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        WalkSession session = walkSessionRepository.save(
                WalkSession.builder()
                        .user(user)
                        .startedAt(LocalDateTime.now())
                        .build()
        );

        return WalkSessionResponse.from(session);
    }

    @Transactional
    public WalkDetailResponse complete(Long userId, Long sessionId, CompleteWalkRequest request) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));

        if (session.getStatus() == Status.COMPLETED) {
            throw BusinessException.badRequest("이미 완료된 산책입니다");
        }

        List<WalkPoint> points = request.points().stream()
                .map(p -> WalkPoint.builder()
                        .session(session)
                        .recordedAt(p.recordedAt())
                        .lat(p.lat())
                        .lng(p.lng())
                        .accuracy(p.accuracy())
                        .build())
                .toList();

        walkPointRepository.saveAll(points);

        int distanceMeters = calculateDistance(request.points());
        int durationSeconds = (int) java.time.Duration.between(
                session.getStartedAt(), request.endedAt()).getSeconds();

        // 완료 전 이번 달 누적 거리 (이 세션 제외)
        LocalDateTime now = request.endedAt();
        int prevMonthlyMeters = walkSessionRepository.sumDistanceByUserAndMonth(
                userId, now.getYear(), now.getMonthValue());

        session.complete(request.endedAt(), distanceMeters, durationSeconds);

        // 완료 후 누적
        int newMonthlyMeters = prevMonthlyMeters + distanceMeters;

        // 달성 알림: 이번 완료로 처음 목표를 넘었을 때만 전송
        sendGoalAchievedNotificationIfNeeded(userId, prevMonthlyMeters, newMonthlyMeters);

        String routeGeoJson = walkPointRepository.findRouteGeoJsonBySessionId(sessionId);
        return WalkDetailResponse.of(session, routeGeoJson);
    }

    private void sendGoalAchievedNotificationIfNeeded(Long userId, int prevMeters, int newMeters) {
        try {
            List<Dog> dogs = dogRepository.findAllByUserId(userId);
            if (dogs.isEmpty()) return;

            Dog representativeDog = dogs.get(0);
            int targetMeters = getMonthlyTargetMeters(representativeDog);

            // 이전엔 미달, 지금은 달성 → 딱 한 번만 전송
            if (prevMeters >= targetMeters || newMeters < targetMeters) return;

            pushSettingRepository.findByUserId(userId).ifPresent(setting -> {
                if (!setting.isWalkReminderEnabled()) return;

                String fcmToken = setting.getUser().getFcmToken();
                if (fcmToken == null || fcmToken.isBlank()) return;

                String dogName = representativeDog.getName();
                fcmService.sendToToken(
                        fcmToken,
                        "🎉 월간 산책 목표 달성!",
                        dogName + "의 꾸준한 산책으로 " + dogName + "이(가) 기뻐해요!"
                );
                log.info("월간 산책 목표 달성 알림 전송: userId={}, dog={}, {}m 달성",
                        userId, dogName, newMeters);
            });
        } catch (Exception e) {
            log.warn("달성 알림 전송 중 오류: {}", e.getMessage());
        }
    }

    /**
     * 견종/체중 기준 월간 최소 권장 산책 거리 (미터)
     * 일일 최소 권장 × 30일
     */
    private int getMonthlyTargetMeters(Dog dog) {
        String breed = dog.getBreed() != null ? dog.getBreed() : "";

        // 고에너지 견종: 8km/일 × 30 = 240km
        if (breed.contains("보더콜리") || breed.contains("도베르만") ||
                breed.contains("달마시안") || breed.contains("비즐라") || breed.contains("와이마라너")) {
            return 240_000;
        }
        // 단두종 (호흡기 약함): 1km/일 × 30 = 30km
        if (breed.contains("프렌치") || breed.contains("불도그") ||
                breed.contains("퍼그") || breed.contains("시추") || breed.contains("페키니즈")) {
            return 30_000;
        }

        // 체중 기반 폴백
        BigDecimal weight = dog.getWeightKg();
        double kg = weight != null ? weight.doubleValue() : 10.0;

        if (kg <= 10) return 45_000;   // 소형견: 1.5km/일 × 30
        if (kg <= 25) return 90_000;   // 중형견: 3km/일 × 30
        return 150_000;                // 대형견: 5km/일 × 30
    }

    @Transactional
    public WalkSessionResponse pause(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        session.pause();
        return WalkSessionResponse.from(session);
    }

    @Transactional
    public WalkSessionResponse resume(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        session.resume();
        return WalkSessionResponse.from(session);
    }

    public List<WalkSessionResponse> getHistory(Long userId, int page, int size) {
        return walkSessionRepository
                .findAllByUserIdOrderByStartedAtDesc(userId, PageRequest.of(page, size))
                .stream()
                .map(WalkSessionResponse::from)
                .toList();
    }

    public WalkDetailResponse getDetail(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        String routeGeoJson = walkPointRepository.findRouteGeoJsonBySessionId(sessionId);
        return WalkDetailResponse.of(session, routeGeoJson);
    }

    // 경로 공개
    @Transactional
    public WalkDetailResponse publish(Long userId, Long sessionId, PublishRouteRequest request) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        if (session.getStatus() != Status.COMPLETED) {
            throw BusinessException.badRequest("완료된 산책만 공개할 수 있습니다");
        }
        session.makePublic(request.title());
        String routeGeoJson = walkPointRepository.findRouteGeoJsonBySessionId(sessionId);
        return WalkDetailResponse.of(session, routeGeoJson);
    }

    // 경로 비공개
    @Transactional
    public void unpublish(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        session.makePrivate();
    }

    // 공개 경로 피드
    public List<PublicRouteResponse> getPublicRoutes(Long userId, int page, int size) {
        return walkSessionRepository.findPublicRoutes(PageRequest.of(page, size)).stream()
                .map(session -> {
                    long likeCount = likeRepository.countBySessionId(session.getId());
                    boolean likedByMe = userId != null && likeRepository.existsBySessionIdAndUserId(session.getId(), userId);
                    boolean bookmarkedByMe = userId != null && bookmarkRepository.existsBySessionIdAndUserId(session.getId(), userId);
                    String routeGeoJson = walkPointRepository.findRouteGeoJsonBySessionId(session.getId());
                    return PublicRouteResponse.of(session, likeCount, likedByMe, bookmarkedByMe, routeGeoJson);
                })
                .toList();
    }

    // 좋아요 토글
    @Transactional
    public boolean toggleLike(Long userId, Long sessionId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        WalkSession session = walkSessionRepository.findById(sessionId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));

        return likeRepository.findBySessionIdAndUserId(sessionId, userId)
                .map(like -> { likeRepository.delete(like); return false; })
                .orElseGet(() -> { likeRepository.save(WalkRouteLike.builder().session(session).user(user).build()); return true; });
    }

    // 북마크 토글
    @Transactional
    public boolean toggleBookmark(Long userId, Long sessionId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        WalkSession session = walkSessionRepository.findById(sessionId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));

        return bookmarkRepository.findBySessionIdAndUserId(sessionId, userId)
                .map(bm -> { bookmarkRepository.delete(bm); return false; })
                .orElseGet(() -> { bookmarkRepository.save(WalkRouteBookmark.builder().session(session).user(user).build()); return true; });
    }

    private int calculateDistance(List<WalkPointRequest> points) {
        if (points.size() < 2) return 0;

        double totalMeters = 0;
        for (int i = 1; i < points.size(); i++) {
            totalMeters += haversine(
                    points.get(i - 1).lat(), points.get(i - 1).lng(),
                    points.get(i).lat(), points.get(i).lng()
            );
        }
        return (int) totalMeters;
    }

    private double haversine(double lat1, double lng1, double lat2, double lng2) {
        final int R = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
