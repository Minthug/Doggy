package com.doggy.backend.domain.walk.dto;

import jakarta.validation.constraints.NotNull;

public record UpdateLocationRequest(
        @NotNull Double lat,
        @NotNull Double lng
) {}
