package com.doggy.backend.domain.household.dto;

import jakarta.validation.constraints.NotBlank;

public record JoinHouseholdRequest(
        @NotBlank String inviteCode
) {}
