package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.walk.dto.*;
import com.doggy.backend.domain.walk.entity.MarkingSpot;
import com.doggy.backend.domain.walk.entity.MarkingSpotVisit;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.repository.MarkingSpotRepository;
import com.doggy.backend.domain.walk.repository.MarkingSpotVisitRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.common.RequestLimits;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MarkingSpotService {

    private static final double GRID_SIZE = 0.0003; // 약 25~35m 단위 공개 좌표
    private static final int MIN_DWELL_SECONDS = 12;
    private static final int MIN_MOVE_BEFORE_METERS = 8;
    private static final int MIN_MOVE_AFTER_METERS = 8;
    private static final int MAX_CANDIDATES = 15;
    private static final int MAX_VISIT_DOGS = 5;

    private final MarkingSpotRepository spotRepository;
    private final MarkingSpotVisitRepository visitRepository;
    private final WalkSessionRepository walkSessionRepository;
    private final DogRepository dogRepository;
    private final HouseholdService householdService;

    public List<MarkingSpotCandidateResponse> detectCandidates(List<WalkPointRequest> points) {
        if (points == null || points.size() < 4) {
            return List.of();
        }

        List<MarkingCandidate> raw = new ArrayList<>();
        raw.addAll(detectGapCandidates(points));
        int start = 0;
        while (start < points.size()) {
            WalkPointRequest anchor = points.get(start);
            int end = start + 1;
            while (end < points.size()
                    && distanceMeters(anchor.lat(), anchor.lng(), points.get(end).lat(), points.get(end).lng()) <= 12) {
                end++;
            }

            if (end - start >= 2) {
                WalkPointRequest first = points.get(start);
                WalkPointRequest last = points.get(end - 1);
                int dwellSeconds = Math.max(0, (int) java.time.Duration.between(first.recordedAt(), last.recordedAt()).getSeconds());
                if (dwellSeconds >= MIN_DWELL_SECONDS && movedBefore(points, start) && movedAfter(points, end - 1)) {
                    double lat = averageLat(points.subList(start, end));
                    double lng = averageLng(points.subList(start, end));
                    raw.add(new MarkingCandidate(lat, lng, first.recordedAt().plusSeconds(dwellSeconds / 2L), dwellSeconds));
                }
            }
            start = Math.max(end, start + 1);
        }

        List<MarkingCandidate> merged = mergeNearbyCandidates(raw);
        if (merged.isEmpty()) {
            return List.of();
        }

        Map<String, MarkingSpot> existingByGridKey = spotRepository.findAllByGridKeyIn(
                        merged.stream().map(c -> gridKey(c.lat(), c.lng())).collect(Collectors.toSet()))
                .stream()
                .collect(Collectors.toMap(MarkingSpot::getGridKey, spot -> spot));

        return merged.stream()
                .sorted(Comparator.comparingInt(MarkingCandidate::dwellSeconds).reversed())
                .limit(MAX_CANDIDATES)
                .map(candidate -> {
                    SnappedCoordinate snapped = snap(candidate.lat(), candidate.lng());
                    MarkingSpot spot = existingByGridKey.get(snapped.gridKey());
                    return new MarkingSpotCandidateResponse(
                            snapped.gridKey(),
                            snapped.lat(),
                            snapped.lng(),
                            candidate.detectedAt(),
                            candidate.dwellSeconds(),
                            spot != null ? spot.getVisitCount() : 0
                    );
                })
                .toList();
    }

    private List<MarkingCandidate> detectGapCandidates(List<WalkPointRequest> points) {
        List<MarkingCandidate> candidates = new ArrayList<>();
        for (int i = 1; i < points.size() - 1; i++) {
            WalkPointRequest previous = points.get(i - 1);
            WalkPointRequest current = points.get(i);
            WalkPointRequest next = points.get(i + 1);

            int gapSeconds = Math.max(0, (int) java.time.Duration.between(current.recordedAt(), next.recordedAt()).getSeconds());
            if (gapSeconds < MIN_DWELL_SECONDS) {
                continue;
            }
            double beforeMeters = distanceMeters(previous.lat(), previous.lng(), current.lat(), current.lng());
            double afterMeters = distanceMeters(current.lat(), current.lng(), next.lat(), next.lng());
            if (beforeMeters >= MIN_MOVE_BEFORE_METERS && afterMeters >= MIN_MOVE_AFTER_METERS) {
                candidates.add(new MarkingCandidate(
                        current.lat(),
                        current.lng(),
                        current.recordedAt().plusSeconds(gapSeconds / 2L),
                        gapSeconds
                ));
            }
        }
        return candidates;
    }

    @Transactional(readOnly = false)
    public MarkingSpotResponse createVisit(Long userId, Long sessionId, CreateMarkingSpotVisitRequest request) {
        validateCoordinate(request.lat(), request.lng());
        WalkSession session = walkSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> BusinessException.notFound("산책 기록을 찾을 수 없습니다"));
        if (session.getStatus() != WalkSession.Status.COMPLETED) {
            throw BusinessException.badRequest("완료된 산책에서만 발자국을 공유할 수 있습니다");
        }

        List<Dog> dogs = accessibleDogs(userId, request.dogIds());
        if (dogs.isEmpty() || dogs.size() != new HashSet<>(request.dogIds()).size()) {
            throw BusinessException.badRequest("공유할 강아지를 선택해주세요");
        }
        if (dogs.size() > MAX_VISIT_DOGS) {
            throw BusinessException.badRequest("한 번에 공유할 수 있는 강아지 수가 너무 많습니다");
        }

        SnappedCoordinate snapped = snap(request.lat(), request.lng());
        MarkingSpot spot = spotRepository.findByGridKey(snapped.gridKey())
                .orElseGet(() -> spotRepository.save(MarkingSpot.builder()
                        .lat(snapped.lat())
                        .lng(snapped.lng())
                        .gridKey(snapped.gridKey())
                        .build()));

        User user = session.getUser();
        LocalDateTime visitedAt = request.detectedAt() != null ? request.detectedAt() : session.getEndedAt();
        if (visitedAt == null) {
            visitedAt = LocalDateTime.now();
        }

        boolean created = false;
        for (Dog dog : dogs) {
            if (visitRepository.existsBySpotIdAndSessionIdAndDogId(spot.getId(), session.getId(), dog.getId())) {
                continue;
            }
            visitRepository.save(MarkingSpotVisit.builder()
                    .spot(spot)
                    .session(session)
                    .dog(dog)
                    .user(user)
                    .visitedAt(visitedAt)
                    .build());
            spot.recordVisit(visitedAt);
            created = true;
        }
        if (!created) {
            throw BusinessException.badRequest("이미 공유한 발자국입니다");
        }
        return MarkingSpotResponse.from(spot);
    }

    public MarkingSpotDetailResponse getDetail(Long spotId) {
        MarkingSpot spot = spotRepository.findById(spotId)
                .orElseThrow(() -> BusinessException.notFound("발자국 스팟을 찾을 수 없습니다"));
        List<MarkingSpotVisitResponse> visits = visitRepository
                .findAllBySpotIdOrderByCreatedAtDesc(spotId, PageRequest.of(0, 30))
                .stream()
                .map(MarkingSpotVisitResponse::from)
                .toList();
        return new MarkingSpotDetailResponse(
                spot.getId(),
                spot.getLat(),
                spot.getLng(),
                spot.getVisitCount(),
                spot.getLastVisitedAt(),
                visits
        );
    }

    public List<MarkingSpotResponse> getSessionSpots(Long sessionId) {
        Map<Long, MarkingSpot> spotsById = new LinkedHashMap<>();
        visitRepository.findAllBySessionIdOrderByCreatedAtDesc(sessionId)
                .forEach(visit -> spotsById.putIfAbsent(visit.getSpot().getId(), visit.getSpot()));
        return spotsById.values().stream()
                .map(MarkingSpotResponse::from)
                .toList();
    }

    private List<Dog> accessibleDogs(Long userId, List<Long> dogIds) {
        Long householdId = householdService.findHouseholdIdByUserId(userId).getId();
        Set<Long> requestedIds = new HashSet<>(dogIds);
        return dogRepository.findAllById(requestedIds).stream()
                .filter(dog -> dog.getUser().getId().equals(userId)
                        || (householdId != null && dog.getHousehold() != null
                        && dog.getHousehold().getId().equals(householdId)))
                .toList();
    }

    private List<MarkingCandidate> mergeNearbyCandidates(List<MarkingCandidate> candidates) {
        List<MarkingCandidate> merged = new ArrayList<>();
        for (MarkingCandidate candidate : candidates) {
            OptionalInt index = findNearbyCandidate(merged, candidate);
            if (index.isPresent()) {
                MarkingCandidate current = merged.get(index.getAsInt());
                if (candidate.dwellSeconds() > current.dwellSeconds()) {
                    merged.set(index.getAsInt(), candidate);
                }
            } else {
                merged.add(candidate);
            }
        }
        return merged;
    }

    private OptionalInt findNearbyCandidate(List<MarkingCandidate> candidates, MarkingCandidate target) {
        for (int i = 0; i < candidates.size(); i++) {
            MarkingCandidate candidate = candidates.get(i);
            if (distanceMeters(candidate.lat(), candidate.lng(), target.lat(), target.lng()) <= 25) {
                return OptionalInt.of(i);
            }
        }
        return OptionalInt.empty();
    }

    private boolean movedBefore(List<WalkPointRequest> points, int index) {
        if (index == 0) {
            return false;
        }
        WalkPointRequest previous = points.get(index - 1);
        WalkPointRequest current = points.get(index);
        return distanceMeters(previous.lat(), previous.lng(), current.lat(), current.lng()) >= MIN_MOVE_BEFORE_METERS;
    }

    private boolean movedAfter(List<WalkPointRequest> points, int index) {
        if (index >= points.size() - 1) {
            return false;
        }
        WalkPointRequest current = points.get(index);
        WalkPointRequest next = points.get(index + 1);
        return distanceMeters(current.lat(), current.lng(), next.lat(), next.lng()) >= MIN_MOVE_AFTER_METERS;
    }

    private double averageLat(List<WalkPointRequest> points) {
        return points.stream().mapToDouble(WalkPointRequest::lat).average().orElse(0);
    }

    private double averageLng(List<WalkPointRequest> points) {
        return points.stream().mapToDouble(WalkPointRequest::lng).average().orElse(0);
    }

    private SnappedCoordinate snap(double lat, double lng) {
        double snappedLat = Math.round(lat / GRID_SIZE) * GRID_SIZE;
        double snappedLng = Math.round(lng / GRID_SIZE) * GRID_SIZE;
        return new SnappedCoordinate(snappedLat, snappedLng, gridKey(snappedLat, snappedLng));
    }

    private String gridKey(double lat, double lng) {
        long latKey = Math.round(lat / GRID_SIZE);
        long lngKey = Math.round(lng / GRID_SIZE);
        return latKey + ":" + lngKey;
    }

    private void validateCoordinate(double lat, double lng) {
        RequestLimits.validateLatLng(lat, lng);
    }

    private double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
        double earthRadius = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return earthRadius * c;
    }

    private record MarkingCandidate(double lat, double lng, LocalDateTime detectedAt, int dwellSeconds) {}

    private record SnappedCoordinate(double lat, double lng, String gridKey) {}
}
