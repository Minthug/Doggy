package com.doggy.backend.global.weather;

public record WalkForecastSlot(
        String timeLabel,
        WalkIndex index,
        String label,
        String emoji,
        int temperature,
        int precipitationProbability,
        String precipitationType,
        boolean isRaining,
        boolean isNight
) {}
