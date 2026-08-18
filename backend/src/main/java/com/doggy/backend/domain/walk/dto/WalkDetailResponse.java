package com.doggy.backend.domain.walk.dto;

import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;

import java.time.LocalDateTime;
import java.util.List;

public record WalkDetailResponse(
        Long id,
        LocalDateTime startedAt,
        LocalDateTime endedAt,
        int distanceMeters,
        int durationSeconds,
        Status status,
        String routeGeoJson,
        List<DogInfo> dogs,
        List<MarkingSpotCandidateResponse> markingSpotCandidates,
        List<MarkingSpotResponse> markingSpots
) {
    public record DogInfo(Long id, String name, String breed, String profileImage) {}

    public static WalkDetailResponse of(WalkSession session, String routeGeoJson) {
        return of(session, routeGeoJson, List.of(), List.of());
    }

    public static WalkDetailResponse of(WalkSession session,
                                        String routeGeoJson,
                                        List<MarkingSpotCandidateResponse> markingSpotCandidates) {
        return of(session, routeGeoJson, markingSpotCandidates, List.of());
    }

    public static WalkDetailResponse of(WalkSession session,
                                        String routeGeoJson,
                                        List<MarkingSpotCandidateResponse> markingSpotCandidates,
                                        List<MarkingSpotResponse> markingSpots) {
        List<DogInfo> dogInfos = session.getDogs().stream()
                .map(d -> new DogInfo(d.getId(), d.getName(), d.getBreed(), d.getProfileImage()))
                .toList();
        return new WalkDetailResponse(
                session.getId(),
                session.getStartedAt(),
                session.getEndedAt(),
                session.getDistanceMeters(),
                session.getDurationSeconds(),
                session.getStatus(),
                routeGeoJson,
                dogInfos,
                markingSpotCandidates != null ? markingSpotCandidates : List.of(),
                markingSpots != null ? markingSpots : List.of()
        );
    }
}
