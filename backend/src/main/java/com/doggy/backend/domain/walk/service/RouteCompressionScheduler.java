package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.repository.WalkPointRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class RouteCompressionScheduler {

    private final WalkSessionRepository walkSessionRepository;
    private final WalkPointRepository walkPointRepository;

    /**
     * 3개월 이상 된 세션: GeoJSON 보존 후 walk_points 삭제.
     * routeGeoJson이 없으면 PostGIS로 생성해서 저장.
     */
    @Scheduled(cron = "0 0 3 * * *")
    @Transactional
    public void compressOldRoutes() {
        LocalDateTime threeMonthsAgo = LocalDateTime.now().minusMonths(3);
        List<WalkSession> sessions =
                walkSessionRepository.findSessionsWithPointsBefore(threeMonthsAgo, 100);

        if (sessions.isEmpty()) return;

        int compressed = 0;
        for (WalkSession session : sessions) {
            try {
                if (session.getRouteGeoJson() == null) {
                    String geoJson = walkPointRepository
                            .findRouteGeoJsonBySessionId(session.getId());
                    session.saveRouteGeoJson(geoJson);
                }
                walkPointRepository.deleteAllBySessionId(session.getId());
                compressed++;
            } catch (Exception e) {
                log.warn("[압축] 실패: sessionId={}, {}", session.getId(), e.getMessage());
            }
        }
        log.info("[압축] 완료: {}개 세션 (3개월 이상)", compressed);
    }

    /**
     * 12개월 이상 된 세션: points 무조건 삭제 (GeoJSON은 이미 저장됨).
     * 압축 단계를 건너뛴 세션에 대한 안전망.
     */
    @Scheduled(cron = "0 30 3 * * *")
    @Transactional
    public void purgeExpiredPoints() {
        LocalDateTime twelveMonthsAgo = LocalDateTime.now().minusMonths(12);
        List<WalkSession> sessions =
                walkSessionRepository.findSessionsWithPointsBefore(twelveMonthsAgo, 500);

        if (sessions.isEmpty()) return;

        List<Long> sessionIds = sessions.stream().map(WalkSession::getId).toList();
        walkPointRepository.deleteAllBySessionIdIn(sessionIds);
        log.info("[삭제] 오래된 walk_points 제거: {}개 세션 (12개월 이상)", sessionIds.size());
    }
}
