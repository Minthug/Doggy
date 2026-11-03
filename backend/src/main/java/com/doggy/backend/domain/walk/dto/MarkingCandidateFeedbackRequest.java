package com.doggy.backend.domain.walk.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.util.List;

public record MarkingCandidateFeedbackRequest(
        @NotEmpty @Size(max = 3) List<@Valid MarkingCandidateAnswer> answers,
        @Size(max = 5) List<@NotNull @Positive Long> dogIds
) {
}
