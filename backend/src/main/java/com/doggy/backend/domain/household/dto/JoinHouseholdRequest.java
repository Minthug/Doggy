package com.doggy.backend.domain.household.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record JoinHouseholdRequest(
        @NotBlank @Pattern(regexp = "[A-Fa-f0-9]{20}") String inviteCode
) {}
