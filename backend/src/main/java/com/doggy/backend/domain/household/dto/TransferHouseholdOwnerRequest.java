package com.doggy.backend.domain.household.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record TransferHouseholdOwnerRequest(@NotNull @Positive Long targetUserId) {}
