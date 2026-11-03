package com.doggy.backend.domain.walk.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record MarkingCandidateAnswer(
        @NotBlank String candidateKey,
        @NotNull Boolean marked
) {
}
