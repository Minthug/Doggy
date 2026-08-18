package com.doggy.backend.domain.walk.dto;

import java.time.LocalDateTime;
import java.util.List;

public record MarkingSpotDetailResponse(
        Long id,
        double lat,
        double lng,
        int visitCount,
        LocalDateTime lastVisitedAt,
        List<MarkingSpotVisitResponse> visits
) {
}
