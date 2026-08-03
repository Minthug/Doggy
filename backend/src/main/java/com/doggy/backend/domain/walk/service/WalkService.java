package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.dto.*;
import com.doggy.backend.domain.walk.entity.WalkRouteBookmark;
import com.doggy.backend.domain.walk.entity.WalkRouteLike;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;
import com.doggy.backend.domain.walk.repository.WalkPointRepository;
import com.doggy.backend.domain.walk.repository.WalkRouteBookmarkRepository;
import com.doggy.backend.domain.walk.repository.WalkRouteLikeRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.common.RequestLimits;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.fcm.FcmService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

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
    private final HouseholdService householdService;
    private final PushSettingRepository pushSettingRepository;
    private final FcmService fcmService;
    private final WalkPingService walkPingService;
    private final JdbcTemplate jdbcTemplate;

    @Transactional(readOnly = false)
    public WalkSessionResponse start(Long userId, StartWalkRequest request) {
        // 비정상 종료로 남은 세션이 있으면 자동 abandon 처리
        try {
            walkSessionRepository.findActiveSession(userId, Status.IN_PROGRESS)
                    .ifPresent(s -> {
                        log.warn("기존 IN_PROGRESS 세션 자동 abandon: sessionId={}", s.getId());
                        s.abandon();
                        walkSessionRepository.saveAndFlush(s);
                    });
            walkSessionRepository.findActiveSession(userId, Status.PAUSED)
                    .ifPresent(s -> {
                        log.warn("기존 PAUSED 세션 자동 abandon: sessionId={}", s.getId());
                        s.abandon();
                        walkSessionRepository.saveAndFlush(s);
                    });
        } catch (Exception e) {
            log.error("기존 세션 abandon 실패 (무시하고 진행): {}", e.getMessage());
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        WalkSession session = WalkSession.builder()
                .user(user)
                .startedAt(LocalDateTime.now())
                .build();

        if (request != null && request.dogIds() != null && !request.dogIds().isEmpty()) {
            Long householdId = householdService.findHouseholdIdByUserId(userId).getId();
            List<Dog> dogs = dogRepository.findAllById(request.dogIds()).stream()
                    .filter(d -> d.getUser().getId().equals(userId)
                            || (householdId != null && d.getHousehold() != null
                                && d.getHousehold().getId().equals(householdId)))
                    .toList();
            session.setDogs(dogs);
        }

        walkSessionRepository.save(session);
        return WalkSessionResponse.from(session);
    }

    @Transactional(readOnly = false)
    public WalkDetailResponse complete(Long userId, Long sessionId, CompleteWalkRequest request) {
        validateCompleteWalkRequest(request);
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));

        if (session.getStatus() == Status.COMPLETED) {
            throw BusinessException.badRequest("이미 완료된 산책입니다");
        }

        if (!request.points().isEmpty()) {
            String sql = "INSERT INTO walk_points (session_id, recorded_at, lat, lng, accuracy) VALUES (?, ?, ?, ?, ?)";
            jdbcTemplate.batchUpdate(sql, request.points(), request.points().size(), (ps, p) -> {
                ps.setLong(1, sessionId);
                ps.setTimestamp(2, Timestamp.valueOf(p.recordedAt()));
                ps.setDouble(3, p.lat());
                ps.setDouble(4, p.lng());
                if (p.accuracy() != null) ps.setFloat(5, p.accuracy());
                else ps.setNull(5, java.sql.Types.FLOAT);
            });
        }

        int distanceMeters = calculateDistance(request.points());
        int durationSeconds = (int) java.time.Duration.between(
                session.getStartedAt(), request.endedAt()).getSeconds();

        LocalDateTime now = request.endedAt();
        int prevMonthlyMeters = walkSessionRepository.sumDistanceByUserAndMonth(
                userId, now.getYear(), now.getMonthValue());

        session.complete(request.endedAt(), distanceMeters, durationSeconds);
        walkPingService.removeLocation(sessionId);

        sendGoalAchievedNotificationIfNeeded(userId, session.getDogs(), prevMonthlyMeters, prevMonthlyMeters + distanceMeters);

        // GeoJSON 생성 후 세션에 저장 (트랜잭션 내 — 방금 INSERT한 points 바로 읽음)
        try {
            String routeGeoJson = walkPointRepository.findRouteGeoJsonBySessionId(sessionId);
            if (routeGeoJson != null) session.saveRouteGeoJson(routeGeoJson);
            return WalkDetailResponse.of(session, routeGeoJson);
        } catch (Exception e) {
            log.warn("경로 GeoJSON 생성 실패: {}", e.getMessage());
            return WalkDetailResponse.of(session, null);
        }
    }

    private void sendGoalAchievedNotificationIfNeeded(Long userId, List<Dog> sessionDogs, int prevMeters, int newMeters) {
        try {
            List<Dog> dogs = sessionDogs.isEmpty()
                    ? dogRepository.findAllByUserId(userId)
                    : sessionDogs;
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
                        dogName + "의 꾸준한 산책으로 " + dogName + "이(가) 기뻐해요!",
                        FcmService.Channel.ACHIEVEMENT
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

    @Transactional(readOnly = false)
    public WalkSessionResponse pause(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        session.pause();
        return WalkSessionResponse.from(session);
    }

    @Transactional(readOnly = false)
    public WalkSessionResponse resume(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        session.resume();
        return WalkSessionResponse.from(session);
    }

    public List<WalkSessionResponse> getHistory(Long userId, int page, int size) {
        Long householdId = householdService.findHouseholdIdByUserId(userId).getId();
        int safePage = RequestLimits.clampPage(page);
        int safeSize = RequestLimits.clampPageSize(size);
        // Step 1: DB LIMIT 적용된 ID 목록 (JOIN FETCH 없이 정확한 페이지네이션)
        // 한 세션에 가구 강아지가 여럿이면 같은 ID가 중복될 수 있으므로 deduplicate 후 재요청
        List<Long> rawIds = walkSessionRepository.findHistoryIdsByUserId(
                userId, householdId, PageRequest.of(safePage, safeSize));
        if (rawIds.isEmpty()) return List.of();
        List<Long> ids = rawIds.stream().distinct().toList();
        // Step 2: dogs 배치 로드 (IN 절 1회, N+1 없음)
        Map<Long, WalkSession> sessionMap = walkSessionRepository.findAllByIdWithDogs(ids)
                .stream().collect(Collectors.toMap(WalkSession::getId, s -> s));
        // Step 1 정렬 순서 유지 (중복 제거 후)
        return ids.stream()
                .map(sessionMap::get)
                .filter(s -> s != null)
                .map(WalkSessionResponse::from)
                .toList();
    }

    @Transactional(readOnly = false)
    public WalkDetailResponse getDetail(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        String routeGeoJson = session.getRouteGeoJson();
        if (routeGeoJson == null) {
            try {
                routeGeoJson = walkPointRepository.findRouteGeoJsonBySessionId(sessionId);
                // 다음 조회부터 즉시 반환되도록 세션에 저장 (lazy-save)
                if (routeGeoJson != null) session.saveRouteGeoJson(routeGeoJson);
            } catch (Exception e) {
                log.warn("경로 GeoJSON 생성 실패 (getDetail): {}", e.getMessage());
            }
        }
        return WalkDetailResponse.of(session, routeGeoJson);
    }

    // 경로 공개
    @Transactional(readOnly = false)
    public WalkDetailResponse publish(Long userId, Long sessionId, PublishRouteRequest request) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        if (session.getStatus() != Status.COMPLETED) {
            throw BusinessException.badRequest("완료된 산책만 공개할 수 있습니다");
        }
        if (!Boolean.TRUE.equals(request.routeDisclosureAccepted())) {
            throw BusinessException.badRequest("산책 경로 공개 안내에 동의해야 합니다");
        }
        session.makePublic(request.title());
        String routeGeoJson = session.getRouteGeoJson();
        if (routeGeoJson == null) {
            try {
                routeGeoJson = walkPointRepository.findRouteGeoJsonBySessionId(sessionId);
                if (routeGeoJson != null) session.saveRouteGeoJson(routeGeoJson);
            } catch (Exception e) {
                log.warn("경로 GeoJSON 생성 실패 (publish): {}", e.getMessage());
            }
        }
        return WalkDetailResponse.of(session, routeGeoJson);
    }

    // 경로 비공개
    @Transactional(readOnly = false)
    public void unpublish(Long userId, Long sessionId) {
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        session.makePrivate();
    }

    private static final double PUBLIC_ROUTE_RADIUS_METERS = 50_000.0; // 50km

    // 공개 경로 피드
    public List<PublicRouteResponse> getPublicRoutes(Long userId, Double lat, Double lng, int page, int size) {
        int safePage = RequestLimits.clampPage(page);
        int safeSize = RequestLimits.clampPageSize(size);
        if (lat != null || lng != null) {
            RequestLimits.validateLatLng(lat, lng);
        }
        List<WalkSession> sessions = (lat != null && lng != null)
                ? walkSessionRepository.findPublicRoutesNearby(lat, lng, PUBLIC_ROUTE_RADIUS_METERS, safeSize, safePage * safeSize)
                : walkSessionRepository.findPublicRoutesByLikes(safeSize, safePage * safeSize);

        if (sessions.isEmpty()) return List.of();

        List<Long> sessionIds = sessions.stream().map(WalkSession::getId).toList();

        // 1 query: dogs fetch join (native query는 JOIN FETCH 불가 → 별도 조회)
        Map<Long, WalkSession> sessionsWithDogs = walkSessionRepository.findAllByIdWithDogs(sessionIds)
                .stream().collect(Collectors.toMap(WalkSession::getId, s -> s));

        // 1 query: 세션별 좋아요 수 일괄 조회
        Map<Long, Long> likeCounts = likeRepository.countBySessionIdIn(sessionIds).stream()
                .collect(Collectors.toMap(row -> (Long) row[0], row -> (Long) row[1]));

        // 1 query: 내가 좋아요한 세션 ID 조회
        Set<Long> likedIds = userId != null
                ? likeRepository.findLikedSessionIds(sessionIds, userId)
                : Set.of();

        // 1 query: 내가 북마크한 세션 ID 조회
        Set<Long> bookmarkedIds = userId != null
                ? bookmarkRepository.findBookmarkedSessionIds(sessionIds, userId)
                : Set.of();

        // GeoJSON 미캐시 세션 ID만 추려서 배치 조회
        List<Long> missingGeoJsonIds = sessions.stream()
                .map(s -> sessionsWithDogs.getOrDefault(s.getId(), s))
                .filter(s -> s.getRouteGeoJson() == null)
                .map(WalkSession::getId)
                .toList();
        Map<Long, String> batchGeoJsonMap = missingGeoJsonIds.isEmpty()
                ? Map.of()
                : walkPointRepository.findRouteGeoJsonBySessionIds(missingGeoJsonIds).stream()
                        .collect(Collectors.toMap(
                                row -> ((Number) row[0]).longValue(),
                                row -> row[1] != null ? (String) row[1] : ""
                        ));

        return sessions.stream()
                .map(session -> {
                    WalkSession s = sessionsWithDogs.getOrDefault(session.getId(), session);
                    String routeGeoJson = s.getRouteGeoJson() != null
                            ? s.getRouteGeoJson()
                            : batchGeoJsonMap.get(s.getId());
                    String publicRouteGeoJson = PublicRoutePrivacy.minimizeGeoJson(routeGeoJson);
                    return PublicRouteResponse.of(
                            s,
                            likeCounts.getOrDefault(s.getId(), 0L),
                            likedIds.contains(s.getId()),
                            bookmarkedIds.contains(s.getId()),
                            publicRouteGeoJson);
                })
                .toList();
    }

    // 좋아요 토글
    @Transactional(readOnly = false)
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
    @Transactional(readOnly = false)
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

    private void validateCompleteWalkRequest(CompleteWalkRequest request) {
        if (request.points().size() > RequestLimits.MAX_WALK_POINTS) {
            throw BusinessException.badRequest("산책 경로 포인트는 최대 " + RequestLimits.MAX_WALK_POINTS + "개까지 저장할 수 있습니다");
        }
        for (WalkPointRequest point : request.points()) {
            RequestLimits.validateLatLng(point.lat(), point.lng());
        }
    }
}
