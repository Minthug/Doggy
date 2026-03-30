package com.doggy.backend.domain.walk.dto;

import com.doggy.backend.domain.walk.entity.WalkSession;

import java.time.LocalDateTime;

public record PublicRouteResponse(
        Long sessionId,
        String title,
        String authorNickname,
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
            long likeCount,
            boolean likedByMe,
            boolean bookmarkedByMe,
            String routeGeoJson) {
        return new PublicRouteResponse(
                session.getId(),
                session.getTitle(),
                session.getUser().getNickname(),
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
