package com.doggy.backend.domain.walk.dto;

public record TodayWalkStatsResponse(
        long totalDistanceMeters,
        long totalDurationSeconds,
        long walkCount
) {}
