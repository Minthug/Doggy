package com.doggy.backend.domain.household.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateHouseholdRequest(
        @NotBlank @Size(max = 50) String name
) {}
