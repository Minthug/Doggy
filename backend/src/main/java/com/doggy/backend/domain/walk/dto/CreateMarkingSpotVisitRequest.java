package com.doggy.backend.domain.walk.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;
import java.util.List;

public record CreateMarkingSpotVisitRequest(
        @NotNull
        Double lat,

        @NotNull
        Double lng,

        LocalDateTime detectedAt,

        @NotEmpty
        @Size(max = 5)
        List<@NotNull @Positive Long> dogIds
) {
}
