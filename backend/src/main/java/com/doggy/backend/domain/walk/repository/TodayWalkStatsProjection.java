package com.doggy.backend.domain.walk.repository;

public interface TodayWalkStatsProjection {
    long getTotalDistanceMeters();
    long getTotalDurationSeconds();
    long getWalkCount();
}
