package com.doggy.backend.domain.supply.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public record UpdateSupplyRequest(
        @NotNull @Min(0) Integer currentGrams,
        @NotNull @Min(0) Integer totalGrams,
        @NotNull @Min(0) Integer dailyGrams,
        @NotNull @Min(0) Double kcalPerKg
) {}
