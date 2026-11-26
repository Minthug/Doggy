package com.doggy.backend.domain.walk.dto;

import java.time.LocalDateTime;

public record PopularMarkingSpotResponse(Long id, double lat, double lng, long dogCount,
        LocalDateTime lastVisitedAt, LocalDateTime lastRainAt, boolean familyVisited) {
}
