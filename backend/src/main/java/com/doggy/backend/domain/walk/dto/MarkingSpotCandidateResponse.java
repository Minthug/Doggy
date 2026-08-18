package com.doggy.backend.domain.walk.dto;

import java.time.LocalDateTime;

public record MarkingSpotCandidateResponse(
        String candidateKey,
        double lat,
        double lng,
        LocalDateTime detectedAt,
        int dwellSeconds,
        int nearbyVisitCount
) {
}
