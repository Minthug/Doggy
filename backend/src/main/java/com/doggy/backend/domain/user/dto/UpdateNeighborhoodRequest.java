package com.doggy.backend.domain.user.dto;

import jakarta.validation.constraints.*;

public record UpdateNeighborhoodRequest(
        @NotBlank @Size(max = 100) String address,
        @NotNull @DecimalMin("-90") @DecimalMax("90") Double lat,
        @NotNull @DecimalMin("-180") @DecimalMax("180") Double lng
) {}
