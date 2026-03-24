package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.dto.*;
import com.doggy.backend.domain.walk.entity.WalkPoint;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;
import com.doggy.backend.domain.walk.repository.WalkPointRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WalkService {

    private final WalkSessionRepository walkSessionRepository;
    private final WalkPointRepository walkPointRepository;
    private final UserRepository userRepository;

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

        session.complete(request.endedAt(), distanceMeters, durationSeconds);

        String routeGeoJson = walkPointRepository.findRouteGeoJsonBySessionId(sessionId);
        return WalkDetailResponse.of(session, routeGeoJson);
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
