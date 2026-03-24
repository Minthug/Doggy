package com.doggy.backend.domain.walk.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDateTime;

public record WalkPointRequest(

        @NotNull
        LocalDateTime recordedAt,

        @NotNull
        Double lat,

        @NotNull
        Double lng,

        Float accuracy
) {}
