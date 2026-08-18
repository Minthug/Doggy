package com.doggy.backend.domain.walk.dto;

import com.doggy.backend.domain.walk.entity.MarkingSpot;

import java.time.LocalDateTime;

public record MarkingSpotResponse(
        Long id,
        double lat,
        double lng,
        int visitCount,
        LocalDateTime lastVisitedAt
) {
    public static MarkingSpotResponse from(MarkingSpot spot) {
        return new MarkingSpotResponse(
                spot.getId(),
                spot.getLat(),
                spot.getLng(),
                spot.getVisitCount(),
                spot.getLastVisitedAt()
        );
    }
}
