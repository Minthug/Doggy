package com.doggy.backend.global.weather;

import java.util.List;

public record WalkForecastResponse(List<WalkForecastSlot> slots) {}
