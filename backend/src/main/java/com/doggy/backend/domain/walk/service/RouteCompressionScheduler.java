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
    private final WalkTracePathService walkTracePathService;

    /**
     * 완료 후 7일이 지난 세션은 통계용 요약 행만 남기고 원본 GPS를 삭제한다.
     * 사용자가 보관한 기록은 원본 좌표가 없는 정규화 경로 데이터만 남긴다.
     */
    @Scheduled(cron = "0 */15 * * * *")
    @Transactional
    public void purgeExpiredWalkDetails() {
        LocalDateTime sevenDaysAgo = LocalDateTime.now().minusDays(7);
        int totalPurged = 0;
        for (int batch = 0; batch < 50; batch++) {
            List<WalkSession> sessions = walkSessionRepository
                    .findTop100ByStatusAndStartedAtBeforeAndDetailsPurgedAtIsNullOrderByStartedAtAsc(
                            WalkSession.Status.COMPLETED, sevenDaysAgo);
            if (sessions.isEmpty()) break;

            int batchPurged = 0;
            for (WalkSession session : sessions) {
                try {
                    if (session.isArchived() && session.getTracePathData() == null) {
                        try {
                            String geoJson = session.getRouteGeoJson();
                            if (geoJson == null) {
                                geoJson = walkPointRepository.findRouteGeoJsonBySessionId(session.getId());
                            }
                            session.archive(walkTracePathService.createPathData(geoJson));
                        } catch (Exception e) {
                            // 흔적 데이터 생성 실패가 개인정보 보관 기한을 늘리면 안 된다.
                            log.warn("[산책 흔적 생성] 실패하더라도 GPS 삭제 진행: sessionId={}, {}",
                                    session.getId(), e.getMessage());
                        }
                    }
                    walkPointRepository.deleteAllBySessionId(session.getId());
                    session.purgeDetails();
                    batchPurged++;
                } catch (Exception e) {
                    log.warn("[산책 상세 삭제] 실패: sessionId={}, {}", session.getId(), e.getMessage());
                }
            }
            totalPurged += batchPurged;
            walkSessionRepository.flush();
            if (batchPurged == 0) break;
        }
        if (totalPurged > 0) {
            log.info("[산책 상세 삭제] 완료: {}개 세션 (7일 경과)", totalPurged);
        }
    }
}
