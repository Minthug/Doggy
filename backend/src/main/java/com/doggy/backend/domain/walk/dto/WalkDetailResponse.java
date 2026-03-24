package com.doggy.backend.domain.walk.dto;

import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;

import java.time.LocalDateTime;

public record WalkDetailResponse(
        Long id,
        LocalDateTime startedAt,
        LocalDateTime endedAt,
        int distanceMeters,
        int durationSeconds,
        Status status,
        String routeGeoJson
) {
    public static WalkDetailResponse of(WalkSession session, String routeGeoJson) {
        return new WalkDetailResponse(
                session.getId(),
                session.getStartedAt(),
                session.getEndedAt(),
                session.getDistanceMeters(),
                session.getDurationSeconds(),
                session.getStatus(),
                routeGeoJson
        );
    }
}
