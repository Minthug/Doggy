package com.doggy.backend.domain.walk.dto;

import com.doggy.backend.domain.walk.entity.WalkSession;

import java.time.LocalDateTime;

public record PublicRouteResponse(
        Long sessionId,
        String title,
        String dogName,
        int distanceMeters,
        int durationSeconds,
        LocalDateTime startedAt,
        long likeCount,
        boolean likedByMe,
        boolean bookmarkedByMe,
        String routeGeoJson
) {
    public static PublicRouteResponse of(
            WalkSession session,
            String dogName,
            long likeCount,
            boolean likedByMe,
            boolean bookmarkedByMe,
            String routeGeoJson) {
        return new PublicRouteResponse(
                session.getId(),
                session.getTitle(),
                dogName,
                session.getDistanceMeters(),
                session.getDurationSeconds(),
                session.getStartedAt(),
                likeCount,
                likedByMe,
                bookmarkedByMe,
                routeGeoJson
        );
    }
}
