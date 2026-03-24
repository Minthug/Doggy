package com.doggy.backend.domain.walk.dto;

import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;

import java.time.LocalDateTime;

public record WalkSessionResponse(
        Long id,
        LocalDateTime startedAt,
        LocalDateTime endedAt,
        int distanceMeters,
        int durationSeconds,
        Status status
) {
    public static WalkSessionResponse from(WalkSession session) {
        return new WalkSessionResponse(
                session.getId(),
                session.getStartedAt(),
                session.getEndedAt(),
                session.getDistanceMeters(),
                session.getDurationSeconds(),
                session.getStatus()
        );
    }
}
