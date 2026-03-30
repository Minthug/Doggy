package com.doggy.backend.domain.walk.dto;

import jakarta.validation.constraints.NotBlank;

public record PublishRouteRequest(
        @NotBlank String title
) {}
