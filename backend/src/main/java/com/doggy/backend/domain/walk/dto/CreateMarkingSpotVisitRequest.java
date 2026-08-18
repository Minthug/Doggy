package com.doggy.backend.domain.walk.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDateTime;
import java.util.List;

public record CreateMarkingSpotVisitRequest(
        @NotNull
        Double lat,

        @NotNull
        Double lng,

        LocalDateTime detectedAt,

        @NotEmpty
        List<Long> dogIds
) {
}
