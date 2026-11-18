package com.doggy.backend.domain.walk.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.util.List;

public record ManualMarkingFeedbackRequest(
        @NotNull Double lat,
        @NotNull Double lng,
        @NotEmpty @Size(max = 5) List<@NotNull @Positive Long> dogIds
) {
}
