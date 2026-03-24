package com.doggy.backend.domain.walk.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDateTime;
import java.util.List;

public record CompleteWalkRequest(

        @NotNull
        LocalDateTime endedAt,

        @NotNull
        List<WalkPointRequest> points
) {}
