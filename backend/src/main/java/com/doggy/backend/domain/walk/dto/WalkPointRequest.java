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

        Float accuracy,

        Boolean segmentStart
) {
    public WalkPointRequest(LocalDateTime recordedAt, Double lat, Double lng, Float accuracy) {
        this(recordedAt, lat, lng, accuracy, false);
    }

    public boolean startsSegment() {
        return Boolean.TRUE.equals(segmentStart);
    }
}
